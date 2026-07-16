# timing doc to keep track of timing issues and how i fixed them

- In post-synthesis STA for systolic_array.sdc: 
    - Managed to reduce The -18.8 ns path (nor2 driving 381 loads) is gone from the report entirely, and worst reg2reg went from `-18.83` to `-0.87`
    - Pipelining the control signals was the fix which i overlooked initially when my array was only 2x2 but when chaning to N=4 the controls were choken from being broadcast.
        - Fix: used shift register to pipeline the control signals
    - Used trimmed lib in another run:
        - in2reg went `-1.04` → `-0.390`
        - reg2reg went `-0.87` → `-0.397`
    - Reduced the huge ~256 fanout to 76 by directly feeding in inputs without buffering them.
        - this was significant because ealier in in2reg path:
            - `delay=10.830   time=11.701 (sky130_fd_sc_hd__nor2_1)`
    - deleted a_r/b_r shadow regs in systolic_array (−256 flops); array reads i_ld_a/i_ld_b (wrapper a_buf/b_buf) directly
    - gated CSR operand writes with !busy in matmul_accel (required: array reads operands live during a job)


## Timing progression (N=4, post-synth sta, tt_025C_1v80, 75 MHz)

| Metric                  | Baseline | ctrl pipelining   | lib trim   |  operand   |
|-------------------------|----------|-------------------|------------|------------|
| Worst reg2reg slack     | -18.83   | -0.87             | -0.79      |    -0.44   |
| Worst in2reg slack      | -1.02    | -1.04             | -0.40      |    +1.18   |
| Worst reg2out slack     | +11.28   | +11.31            | +11.14     |    +7.82   |
| Worst fanout (one net)  | 381      | 278               | 281        |76 (ctrl-ff)|
| Worst slew on that net  | 10.3 ns  | 16.2 ns           | 15.4 ns    |    1.4 ns  |
| lpflow cells in netlist | yes      | yes               | no         |      no    |

Reference: N=2 worst reg2reg = +5.39 (PE MAC chain, ~20 stages, unchanged by array size)

