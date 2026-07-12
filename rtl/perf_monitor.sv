// NOT FOR SYNTHESIS
// THIS PEROFRMANCE MONITOR WAS GENERATED WITH CLAUDE (i was tired)
`default_nettype none
`timescale 1ps/1ps

/*
generate
        if (PERF_COUNTER_EN) begin : gen_perf_counters
            wire monitor_mem_access = !sram_csb || !feed_csb;

            perf_monitor perf_inst (
                .clk         (clk),
                .rstn        (rstn),
                .i_run_start (start_pulse && !status_busy),
                .i_run_done  (done_set),
                .i_busy      (status_busy),
                .i_load      (feed_active),
                .i_compute   (pe_enable),
                .i_writeback (engine_ownd),
                .i_mem_access(monitor_mem_access),
                .i_csr_wr    (csr_wr),
                .i_csr_rd    (csr_rd)
            );
        end
endgenerate
*/

module perf_monitor #(
    parameter bit VERBOSE = 1'b1
)(
    input wire clk,
    input wire rstn,

    input wire i_run_start,
    input wire i_run_done,
    input wire i_busy,
    input wire i_load,
    input wire i_compute,
    input wire i_writeback,
    input wire i_mem_access,
    input wire i_csr_wr,
    input wire i_csr_rd
);
    int unsigned total_cycles = 0;
    int unsigned busy_cycles = 0;
    int unsigned load_cycles = 0;
    int unsigned compute_cycles = 0;
    int unsigned wb_cycles = 0;
    int unsigned mem_accesses = 0;
    int unsigned csr_writes = 0;
    int unsigned csr_reads = 0;

    int unsigned starts = 0;
    int unsigned runs = 0;
    int unsigned cur_run = 0;
    int unsigned sum_runs = 0;
    int unsigned min_run = 32'hFFFF_FFFF;
    int unsigned max_run = 0;

    always @(posedge clk) begin
        if (rstn) begin
            total_cycles = total_cycles + 1;
            if (i_busy) busy_cycles = busy_cycles + 1;
            if (i_load) load_cycles = load_cycles + 1;
            if (i_compute) compute_cycles = compute_cycles + 1;
            if (i_writeback) wb_cycles = wb_cycles + 1;
            if (i_mem_access) mem_accesses = mem_accesses + 1;
            if (i_csr_wr) csr_writes = csr_writes + 1;
            if (i_csr_rd) csr_reads = csr_reads + 1;

            if (i_run_start) begin
                starts = starts + 1;
                cur_run = 0;
            end
            if (i_busy) cur_run = cur_run + 1;
            if (i_run_done) begin
                runs = runs + 1;
                sum_runs = sum_runs + cur_run;
                if (cur_run < min_run) min_run = cur_run;
                if (cur_run > max_run) max_run = cur_run;
                if (VERBOSE)
                    $display("[perf %m] t=%0t run %0d done: %0d cycles", $time, runs, cur_run);
            end
        end
    end

    task report;
        begin
            $display("[perf %m] ---- summary t=%0t ----", $time);
            $display("[perf %m] cycles: total=%0d busy=%0d load=%0d compute=%0d writeback=%0d",
                     total_cycles, busy_cycles, load_cycles, compute_cycles, wb_cycles);
            $display("[perf %m] access: sram=%0d csr_wr=%0d csr_rd=%0d",
                     mem_accesses, csr_writes, csr_reads);
            if (runs != 0)
                $display("[perf %m] runs: done=%0d started=%0d latency min/avg/max = %0d/%.1f/%0d",
                         runs, starts, min_run, $itor(sum_runs)/runs, max_run);
            else
                $display("[perf %m] runs: none completed (started=%0d)", starts);
        end
    endtask

endmodule
`default_nettype wire
