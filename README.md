# sky130 4×4 int8 systolic matmul accelerator

Weight-stationary 4×4 int8 matrix-multiply accelerator with AXI4-Lite control,
two AXI4 master DMA ports and a ping-pong SRAM-macro input buffer. RTL to GDSII
on sky130A with LibreLane.

Closed at 10 ns (100 MHz), all nine signoff corners clean (`runs/final`, 2026-08-09).

| Check | Result |
| --- | --- |
| Setup | 0 violations, worst slack +0.502 ns (`max_ss_100C_1v60`) |
| Hold | 0 violations, worst slack +0.145 ns (`max_ff_n40C_1v95`) |
| Magic / KLayout / routing DRC | 0 / 0 / 0 |
| LVS, antenna, illegal overlaps, GDS XOR | 0 |
| Max slew / cap / fanout | 24 / 1 / 2, characterised below |

---

## Architecture

```
top
├── reset_sync_2ff        async-assert / sync-release reset
├── axi_lite_csr          AXI4-Lite slave, 7 registers (+ 2× skid_buffer)
├── axi4_dma              AXI4 master read, operand fetch
├── axi4_dma_wr           AXI4 master write, result store
├── pp_buf_sram           ping-pong operand buffer, 2× sram22_64x32m4w8
│   └── sram_rst_rel      staged reset release for the macros
├── array_control         job sequencer, tile retire, credit accounting
├── systolic_array        4×4 PE grid, no FSM
│   └── pe                2-stage MAC, registered product (PE_LATENCY = 2)
└── res_cap_fifo          18-bit exact result packer, 9 beats per tile
```

B loads into the PEs and stays put, A streams in as a wavefront from the left,
partial sums accumulate downward. The array has no state machine: every enable
and result-valid is a tap on one `vld_r` delay line fed by `i_a_valid`.

Reads and writes overlap in steady state, so the three AXI ports stay separate.
One shared port would need an arbiter and serialise the overlap.

Tile results are partial sums, stored as exact 18-bit values. For K larger than
`MATRIX_SIZE` software accumulates across tiles, so clipping would compound.
16 × 18b is exactly 9 beats. Never narrow this format; `test_extremes` is the
only test that catches it.

Memory: `sram22_64x32m4w8` ×2, 64 words × 32 bit, single RW port. Placed at
(14.88, 446.86) and (382.88, 446.86), orientation N so all met1 pins face south
into the logic. Deliberately oversized, 8 of the 64 words are reachable.

---

## Register map

AXI4-Lite, 32-bit, 7 registers.

| Offset | Name | Access | Notes |
| --- | --- | --- | --- |
| `0x00` | CTRL | RW | 6 bits: EN, GO, LOAD_W, STORE, AUTO_ST, AUTO_FILL |
| `0x04` | STATUS | RO | see below |
| `0x08` | SRC_ADDR | RW | operand fetch base |
| `0x0C` | LEN | RW | 7 bits |
| `0x10` | RESULT | RO | pop-on-read |
| `0x14` | DST_ADDR | RW | result store base |
| `0x18` | NJOBS | RW | 16 bits |

STATUS packs `dma_busy/done/err`, `fill_done`, `ctrl_busy`, `array_busy/done`,
`pp_sel`, `w_valid`, `res_valid`, `res_ovf`, `wdma_busy/done/err`, `af_busy`,
a FIFO level field and a 4-bit tile counter.

Descriptor registers truncate in hardware: writing `0xFFFFFFFF` to `LEN` reads
back `0x7F`. Deliberate, and checked by the testbench.

Software must not read `RESULT` while auto-store is active. Reading it during a
store returns data without popping.

---

## Repo layout

```
rtl/                SystemVerilog sources (+ the sram22 behavioural model)
tb/                 cocotb (test_top.py) + self-contained SV (tb_top.sv)
constraints/        base.sdc, pnr.sdc, signoff.sdc, pin_order.cfg
scripts/            macro build, STA debug, PDN and report helpers
sram22_64x32m4w8/   vendor macro views (committed pre-patched)
config.json         LibreLane configuration
```

`constraints/base.sdc` holds the real clock. `CLOCK_PERIOD` in `config.json`
only feeds ABC during synthesis; PnR and signoff read `PNR_SDC_FILE` and
`SIGNOFF_SDC_FILE`. A commit that moved the clock to 100 MHz once left
`base.sdc` at 5.0 ns and the design closed silently at 200 MHz.

`set_max_transition` is stage-specific on purpose:

| file | value | why |
| --- | --- | --- |
| `base.sdc` | none | comment only |
| `pnr.sdc` | 0.85 | over-constrain so the resizer keeps working |
| `signoff.sdc` | 1.50 | the real `sky130_fd_sc_hd` `default_max_transition` |

Relaxing it in `base.sdc` would relax the resizer's target too and produce worse
real slew.

---

## Building

```sh
make lint                  # verilator -Wall --timing, RTL stays warning-free
make cocotb                # primary regression, 6 tests vs a numpy golden model
make xrun                  # SV bench under Vivado xsim
make vectors               # regenerate tb/vectors/{stim,golden}.hex
```

Physical:

```sh
make sram                  # build the macro views, required before any PnR run
make report  RUN=<tag>     # signoff + timing summary
make sta-shell RUN=<tag> CORNER=max_ss_100C_1v60
make lib-last_run          # OpenROAD GUI on the last run
make gl RUN=<tag>          # gate-level sim on that run's netlist
```

`make sram` is not optional on a fresh checkout, `build/` is gitignored.

---

## Signoff

10 ns, extracted parasitics, all nine corners:

| Corner | Setup WS | Setup TNS | #Setup | Hold WS | #Hold | Max slew |
| --- | --- | --- | --- | --- | --- | --- |
| nom_tt_025C_1v80 | 3.6163 | 0.000 | 0 | 0.2778 | 0 | 4 |
| nom_ss_100C_1v60 | 0.5810 | 0.000 | 0 | 0.5963 | 0 | 18 |
| nom_ff_n40C_1v95 | 4.0460 | 0.000 | 0 | 0.1532 | 0 | 4 |
| min_tt_025C_1v80 | 3.6392 | 0.000 | 0 | 0.2825 | 0 | 4 |
| min_ss_100C_1v60 | 0.6682 | 0.000 | 0 | 0.5547 | 0 | 8 |
| min_ff_n40C_1v95 | 4.0613 | 0.000 | 0 | 0.1590 | 0 | 4 |
| max_tt_025C_1v80 | 3.5846 | 0.000 | 0 | 0.2716 | 0 | 4 |
| max_ss_100C_1v60 | **0.5018** | 0.000 | 0 | 0.5917 | 0 | **24** |
| max_ff_n40C_1v95 | 4.0240 | 0.000 | 0 | **0.1453** | 0 | 7 |

### Design stats

| Metric | Value |
| --- | --- |
| Die area | 502,425 µm² (758.08 × 662.76) |
| Core area | 470,451 µm² |
| Utilisation | 69.0 % |
| Instances | 57,050 |
| sequential | 2,120 |
| multi-input combinational | 11,307 |
| buffers (all) | 1,303 |
| timing-repair buffers | 922 |
| clock buffers / inverters | 381 / 151 |
| clock gates | 51 |
| tap / fill | 4,474 / 37,044 |
| antenna diodes | 329 |
| macros | 2 |
| Power (total) | 11.9 mW |
| internal / switching / leakage | 7.92 mW / 3.99 mW / 0.34 µW |
| Wirelength | 528,547 µm |
| Vias | 127,033 |
| IR drop worst / avg | 0.781 mV / 65.6 µV |
| Clock skew (worst setup, nom_ss) | 1.406 ns |

Skew there is a maximum over all register pairs, including pairs with no timing
path between them. It says nothing about any particular failing path.

### Accepted violations

27 total, all characterised. None gate the design.

| Group | Count | Why it stays |
| --- | --- | --- |
| `rstb` net (`u_m0/m1/rstb`, `_24560_/D`, `_24561_/Q`) | 4 slew + the 1 max_cap | `opt_merge` collapses the two `sram_rst_rel` instances, so one flop drives both macros 368 µm apart at 0.70 pF. Held by `RSZ_DONT_TOUCH_RX`, so no tool may buffer it. Async reset, released once at startup |
| `u_sram.u_m*/din[*]` | 20 slew, 1.51 to 1.86 ns | Shared `i_dma_wdata` to both macros. AXI-group paths arrive ~4 ns into a 10 ns period, so a slow edge on a long-stable data input is benign |
| `place1029/X`, `clkbuf_3_0__f__11155_/X` | 2 fanout (23, 21 vs 20) | Neither appears in any slew list |

SDC cannot waive these. OpenSTA uses `min(sdc_limit, liberty_limit)`, so
`set_max_transition` and `set_max_capacitance` can only tighten a
library-derived limit. `set_max_capacitance 0.80 [get_pins {_24561_/Q}]` was
tried, did reach the generated SDC, and the report still showed the `dfrtp_2`
limit of 0.203257. The only mechanisms are a physical fix or checker scoping via
`MAX_CAP_VIOLATION_CORNERS` / `MAX_SLEW_VIOLATION_CORNERS`.

Watch the object-type asymmetry, which aborts the flow: `set_max_capacitance`
accepts pins, `set_max_transition` does not (clocks, cells and ports only).
Passing a pin gives `Error: unsupported object type Pin`.

---

## How timing was closed

**1. `DESIGN_REPAIR_REMOVE_BUFFERS: true` cost a whole run.** It deletes the
buffer trees synthesis already built. Off, `repair_design` upsizes drivers (180
resized, 180 buffers). On, it chains minimum-size `buf_1`s (49 resized, 981
buffers), two stages at fanout 16 burning 2.84 ns, 28 % of the period, on a PE
weight broadcast. Setup went +0.4801 to -0.7564 and slew 1310 to 5472.
`Resized >> Inserted` is the healthy shape for that step.

**2. The pre-route RC model was 2.03× optimistic, the root cause.**
`SIGNAL_WIRE_RC_LAYERS` was unset, so LibreLane averaged met1 to met5 and
modelled signal wire R at `4.402703e-04` kΩ/µm. Local nets actually route on
met1/met2 at `8.928571e-04`. Every pre-route decision (driver sizing, `buf_1` vs
`buf_4`, buffer count) was made against half the real resistance. Setting it to
`["met1","met2"]` took setup +0.0837 to **+0.5018**.

**3. Both post-GRT gates defaulted off.** `RUN_POST_GRT_DESIGN_REPAIR` and
`RUN_POST_GRT_RESIZER_TIMING` were `false`, so `GRT_RESIZER_SETUP_SLACK_MARGIN`,
`GRT_RESIZER_HOLD_SLACK_MARGIN` and every `GRT_DESIGN_REPAIR_*` were set and
never read. Enable them together: resizer-timing defends setup while
design-repair inserts buffers for slew.

**4. 1296 of 1320 slew violations were self-inflicted.** `base.sdc` set
`set_max_transition 0.85` against the PDK's `default_max_transition : 1.5000`,
1.76× tighter than sky130 requires. At the PDK limit only 24 remain.

Two traps:

- GRT-stage DRV numbers are unusable. Even after the RC fix, post-GRT STA
  reported 4 slew violations against post-RCX's 1320, because the estimation
  model carries via resistance as all zeros while `mcon` alone is 9.3e-03 kΩ/cut.
  Never A/B a buffering change on a pre-RCX step.
- Check `<step>/top.sdc` before believing any constraint-shaped config key.
  `MAX_TRANSITION_CONSTRAINT` (0.75) and `MAX_FANOUT_CONSTRAINT` (10) read as set
  in `resolved.json` but are inert, because the project supplies `PNR_SDC_FILE`
  and `base.sdc` wins.

Measured and rejected: excluding `buf_1` does not help. Of the 1320 violating
pins only 80 sit on `buf_1`. The bulk are input pins of ordinary 2× logic
receiving bad slew, `a221o_2` (194), `a22o_2` (152), `nand4_2` (73). That is
distributed marginal slew, not a buffer-sizing problem.

---

## Limitations

- The `rstb` merge is not defeated. A `(* keep_hierarchy *)` boundary works only
  under yosys's native frontend; `USE_SLANG: true` drops the attribute, so
  `FLATTEN` removes the boundary and `OPT_MERGE` re-collapses the chains.
  `(* keep *)` on the reg pins the net name while the cells still merge. A real
  fix has to make the two chains' inputs structurally different.
- `RSZ_DONT_TOUCH_RX` must stay an active key. Commenting it out is not neutral,
  LibreLane's default is `"$^"`, which protects nothing. It matches net names
  against a flattened netlist, so an RTL rename can silently evaporate the
  protection and kill global placement with a fatal `RSZ-2008`. It is now
  `"u_sram.*(rstb|rel_r).*"`, widened to match both spellings.
- Macro Y, the halo and the core top are coupled. Y must satisfy
  `(y + 0.07 - 0.17) / 0.34 = integer` for the met1 pins to land on track. A
  drift to 447.16 put 0 of 78 pins on-track and produced ~150 `DRT-0419`
  warnings. 446.86 aligns and leaves 0.300 µm of halo headroom. Macro X cannot
  be aligned, the 6.10 µm pin pitch against the 0.46 µm met2 pitch is
  incommensurate.
- All 2.46 M Magic GDS DRC errors are inside the macro, verified by testing
  every bounding box against the two footprints. Handled with
  `MAGIC_DRC_MAGLEFS`. Do not "fix" it with `MAGIC_DRC_USE_GDS: false`.
- `RES_JOBS` is set to 2, the measured optimum is 3.
- No DFT: no scan, no JTAG, no test-mode reset bypass.
- `make sta` is stale, it reads a deleted `constraints/top.sdc` and probes
  `u_array.current_state`, which no longer exists.
- ~13 % throughput headroom remains, needing the AW channel pipelined across
  bursts. Not verifiable on the current benches, both write slaves are strictly
  serial. Upgrading the bench model is the prerequisite.
