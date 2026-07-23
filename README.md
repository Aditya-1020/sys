# sky130 4×4 int8 systolic matmul accelerator

A weight-stationary 4×4 int8 matrix-multiply accelerator with an SPI slave
control interface and an SRAM-backed input queue, taken from RTL to a clean
GDSII on sky130A with LibreLane.

**Status: closed at 12 ns (83.3 MHz), all nine signoff corners clean.**

| Check | Result |
| --- | --- |
| Setup violations | **0** — worst slack **+0.232 ns** (`max_ss_100C_1v60`) |
| Hold violations | **0** — worst slack **+0.197 ns** (`max_ff_n40C_1v95`) |
| Magic DRC | 0 |
| KLayout DRC | 0 |
| Routing DRC (DRT) | 0 |
| LVS | 0 |
| Antenna | 0 |
| PDN | 0 |
| Illegal overlaps | 0 |
| Disconnected pins | 0 |

---

## Architecture

```
top
├── reset_sync_2ff          async-assert / sync-release reset
├── spi_if                  SPI slave (mode 0), CDC into the core clock
└── matmul_accel
    ├── ctrl_unit           CSR block + A-row serialiser + job sequencer
    ├── in_fifo             16-slot matrix queue, sky130 SRAM macro backed
    ├── systolic_array      4×4 PE grid + result buffer + result streamer
    └── out_fifo            16-deep FWFT result FIFO
```

The array is weight-stationary: B is loaded into the PEs one lane at a time and
stays put, A streams in as a wavefront from the left, and partial sums
accumulate downward. Jobs auto-launch whenever `CTRL.EN` is set and a complete
matrix is queued; the controller only starts when the array is idle and
completes on the array's sticky `o_done`.

Each PE is a 2-stage pipeline (`a_r → mult_r → accumulator`, `PE_LATENCY = 2`)
— the registered product is what keeps the 8×8 multiply off the critical path.

### Memory macro

`sky130_sram_256byte_1rw1r_32x64_8` — 64 words × 32 bit, dual-port (1RW + 1R),
generated with OpenRAM. Port 0 is the write port, port 1 is the read port. The
macro is placed manually at `(30, 605)` with a 10 µm halo.

---

## SPI protocol

Mode 0, `sclk` up to `clk/2`. A frame is:

```
CS# low → [8 command bits] → [8 turnaround bits, reads only] → [32-bit words…] → CS# high
```

Multiple data words may follow one command; `CS#` rising ends the frame.

| Command | Meaning |
| --- | --- |
| `0x8n` | CSR write, `n[1:0]` selects the register |
| `0x0n` | CSR read, `n[1:0]` selects the register |
| `0xA0` | A-matrix write — 4 words = one 4×4 matrix |
| `0xB0` | B-weight write — 4 words, one per lane (dropped while busy) |
| `0x40` | C result read — pop-on-read, sign-extended to 32 bit |

CSR select `n[1:0]`: `0` = CTRL, `1` = STATUS, `2` = IRQ.

| Register | Fields |
| --- | --- |
| CTRL | `[0]` EN, `[1]` IRQ_EN |
| STATUS | `[0]` busy, `[1]` a-empty, `[2]` a-full, `[3]` done, `[4]` res-valid, `[15:8]` a-level, `[23:16]` res-level |
| IRQ (w1c) | `[0]` job-irq, `[1]` a-overflow |

The CSR bus contract is that `i_en` is a **single-cycle strobe** — the SPI
bridge guarantees this, and pop-on-read depends on it.

---

## Repo layout

```
rtl/            SystemVerilog sources (+ the OpenRAM behavioural model)
tb/             testbenches
constraints/    base.sdc + pnr.sdc + signoff.sdc
scripts/        synth/STA tcl, report generator, STA debug shell, lib filter
sram_32x64/     generated SRAM macro (gds/lef/lib/spice/v)
docs/           flow, PD and timing notes kept during bring-up
config.json     LibreLane configuration
```

`constraints/base.sdc` holds the real clock definition. **`CLOCK_PERIOD` in
`config.json` only feeds ABC during synthesis** — PnR and signoff read
`PNR_SDC_FILE` / `SIGNOFF_SDC_FILE`. Keep the two in sync.

---

## Building

Simulation runs through sv2v → Vivado xsim.

```sh
make lint                       # verilator -Wall, RTL must stay warning-free
make xrun TOP=tb_systolic_array # tb_csr, tb_ctrl_unit, tb_in_fifo, tb_sram,
                                # tb_matmul_accel, tb_top
make gls                        # gate-level sim against the synth netlist
make sta STA_TOP=pe             # standalone OpenSTA on a submodule
```

Physical implementation:

```sh
make liblane RUN=<tag>          # full RTL→GDSII
make report  RUN=<tag>          # signoff + timing summary table
make sta-shell RUN=<tag> CORNER=nom_ss_100C_1v60   # interactive STA on a run
```

`make liblane` runs LibreLane to KLayout stream-out, strips orphan tops from the
Magic GDS, then finishes the render.

---

## How timing was closed

The clock came down from an optimistic early target to a solid 12 ns. Most of
the work was structural rather than constraint tweaking.

### 1. Control broadcast (N=2 → N=4)

Scaling the array from 2×2 to 4×4 turned a comfortable design into a badly
violating one: worst reg-to-reg slack **−18.83 ns**, caused by a single `nor2`
driving **381 loads** with a 10.3 ns slew. At N=2 the broadcast was small enough
to hide.

Pipelining the control signals into shift registers so each column gets its own
registered copy fixed it: **−18.83 → −0.87 ns**.

### 2. Library trimming

The `lpflow_*` and `probe_*` cells were being selected by ABC and were poor
timing choices. `scripts/filter_lib.py` strips them from the Liberty file before
synthesis:

- in2reg **−1.04 → −0.390 ns**
- reg2reg **−0.87 → −0.397 ns**

`EXTRA_EXCLUDED_CELLS` in `config.json` keeps them out of the PnR resizer too,
along with the delay-buffer and tristate families.

### 3. Operand feed

Deleting the `a_r`/`b_r` shadow registers in `systolic_array` removed 256 flops
and let the array read `i_ld_a`/`i_ld_b` directly. CSR operand writes are gated
with `!busy`, since the array reads its operands live during a job. Worst-net
fanout dropped **381 → 76**, worst slew **15.4 ns → 1.4 ns**, and in2reg went
**−0.40 → +1.18 ns**.

### 4. Timing evolution

| Stage | tt setup WS | ss setup WS | ff setup WS | #Setup | Hold WS | #Hold |
| --- | --- | --- | --- | --- | --- | --- |
| post-synth | 4.926 | 1.881 | 5.136 | 0 | 0.079 | 0 |
| mid-PnR (placement) | — | 1.881 | — | 2 | 0.063 | 0 |
| mid-PnR (post-CTS) | — | 1.881 | — | 0 | 0.101 | 0 |
| mid-PnR (post-GRT) | — | 1.881 | — | 0 | 0.102 | 0 |
| **post-PnR (extracted)** | **3.863** | **0.232** | **4.307** | **0** | **0.197** | **0** |

Mid-PnR STA runs the default corner only, which is why `tt`/`ff` are blank there.

---

## Findings worth keeping

Four issues cost real debugging time and are each easy to walk into again.

### The SDC period was not what the config said

`config.json` had `CLOCK_PERIOD` set to the intended target while
`constraints/base.sdc` still carried an older, much tighter `SYS_PERIOD`. Because
`CLOCK_PERIOD` only reaches ABC, synthesis was optimising for one number and
PnR/signoff were checking against another. Always change the period in the SDC.

### Synthesis and the resizer were only seeing the typical corner

`SYNTH_CORNER` and `PNR_CORNERS` defaulted to `nom_tt` only. At 12 ns the
typical corner passes almost trivially, so the slow corner — roughly 2.3× tt —
was never repaired by the resizer and only showed up at signoff. Fixed by
setting:

```json
"SYNTH_CORNER":   "nom_ss_100C_1v60",
"PNR_CORNERS":    ["nom_tt_025C_1v80", "nom_ss_100C_1v60", "nom_ff_n40C_1v95"],
"DEFAULT_CORNER": "nom_ss_100C_1v60"
```

### The SRAM launches read data on the falling edge

This was the last blocker, and the interesting one. 26 of the 28 remaining
violating paths started at the SRAM, worst slack **−1.569 ns**.

The macro's Liberty declares the `dout1` arc as `timing_type : falling_edge`
(the OpenRAM behavioural model agrees — `always @(negedge clk1)`). Address is
captured on the rising edge, data is driven on the *following falling* edge. So
with `clk1` tied to `clk`, the whole `sram → rd_data` path only ever had **half
a period** — 6 ns of the 12 ns.

It made it through post-synthesis STA at **+1.571 ns** because the resizer was
working from GRT-estimated parasitics. RC extraction then put ~150 fF on the
`dout1` nets, which is more than 5× past the last point the `.lib` characterises
(27.6 fF), so STA extrapolated clk→q out to **5.79 ns** with a 3.1 ns output
slew. Of a 6 ns budget, 5.79 ns was gone before the signal left the macro.

The fix is to feed port 1 the **inverted** clock:

```systemverilog
wire clk_rd = ~clk;
...
.clk1(clk_rd),
```

The macro now samples `addr1`/`csb1` on the falling edge of `clk` (they come
straight off flops, so half a period of setup is ample) and launches `dout1` on
the rising edge — a full period before `rd_data` captures it. Read latency is
unchanged; this was verified by diffing `tb_in_fifo` output before and after,
which is bit-identical every cycle.

Two supporting changes went in alongside it:

- `constraints/pnr.sdc` pins `set_max_capacitance 0.025` on `sram/dout1[*]` so
  `repair_design` buffers at the macro instead of leaving STA to extrapolate.
  PnR-only, so signoff still reports real numbers.
- `RUN_POST_GRT_DESIGN_REPAIR` and `RUN_POST_GRT_RESIZER_TIMING` are enabled.
  Both default to **off**, which is why nothing was re-optimised once real
  routing parasitics existed.

Result: **−1.569 → +0.232 ns**, and the SRAM path left the critical list
entirely. The limiter is now a PE operand-broadcast path, which is the
design-limited path you would expect.

### GDS XOR is an abstract-view artifact

Magic and KLayout stream the macro differently — Magic streams it abstracted
from the LEF, KLayout streams the real geometry — so all ~529k XOR differences
sit inside the macro bounding box. Magic DRC ran against the maglef and flagged
`nwell.4` rows that do contain taps (verified in the DEF at 25.76 µm pitch) and
`met4.4a` on what are SRAM LEF pin stubs.

Neither is a layout defect. Signoff coverage is the KLayout full-deck DRC plus
LVS, both clean, so `RUN_KLAYOUT_XOR` is off.

---

## Signoff

Final results at 12 ns, extracted parasitics, all nine corners:

| Corner | Setup WS | Setup TNS | #Setup | Hold WS | Hold TNS | #Hold |
| --- | --- | --- | --- | --- | --- | --- |
| nom_tt_025C_1v80 | 4.074 | 0.000 | 0 | 0.351 | 0.000 | 0 |
| nom_ss_100C_1v60 | 0.501 | 0.000 | 0 | 0.718 | 0.000 | 0 |
| nom_ff_n40C_1v95 | 4.518 | 0.000 | 0 | 0.199 | 0.000 | 0 |
| min_tt_025C_1v80 | 4.521 | 0.000 | 0 | 0.351 | 0.000 | 0 |
| min_ss_100C_1v60 | 0.771 | 0.000 | 0 | 0.704 | 0.000 | 0 |
| min_ff_n40C_1v95 | 4.953 | 0.000 | 0 | 0.200 | 0.000 | 0 |
| max_tt_025C_1v80 | 3.863 | 0.000 | 0 | 0.351 | 0.000 | 0 |
| max_ss_100C_1v60 | **0.232** | 0.000 | 0 | 0.733 | 0.000 | 0 |
| max_ff_n40C_1v95 | 4.307 | 0.000 | 0 | **0.197** | 0.000 | 0 |

### Design stats

| Metric | Value |
| --- | --- |
| Die area | 475,950 µm² (570 × 835) |
| Core area | 405,418 µm² |
| Utilisation | 74.2 % |
| Instances | 52,924 |
| — sequential | 1,739 |
| — combinational | 13,731 |
| — timing-repair buffers | 1,482 |
| — clock buffers | 277 |
| — macros | 1 |
| — antenna diodes | 42 |
| Power (total) | 13.5 mW |
| — internal / switching / leakage | 10.1 mW / 3.16 mW / 175 µW |
| Wirelength | 552,475 µm |
| Vias | 148,071 |
| IR drop worst / avg | 1.14 mV / 111 µV |
| Clock skew setup / hold | 0.358 / −0.277 ns |

---

## Notes and limitations

- **The SRAM Liberty is TT-only.** There is no ss/ff characterisation for the
  macro, so slow- and fast-corner STA uses the typical macro model. Timing
  margin on macro paths is therefore softer than it looks. The inverted read
  clock helps here too — it buys a full period instead of half, which absorbs a
  lot of uncharacterised variation.
- Max-slew, max-cap and max-fanout report WARN-level counts. These are advisory,
  concentrated on the same macro output nets, and do not gate signoff.
- Two floating nets are reported by the resizer; both are unused macro outputs
  (`dout0`, which the design does not read).
- `RUN_KLAYOUT_XOR` is disabled — see the finding above.
- `tb_systolic_array` is the up-to-date reference testbench (194/194). Some of
  the older block-level testbenches lag the current RTL interfaces.
