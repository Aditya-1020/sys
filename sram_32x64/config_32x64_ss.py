# SS corner characterization (setup-critical: matches std-cell ss_100C_1v60)
# run from ~/tools/openram/OpenRAM:
#   venv/bin/python3 sram_compiler.py <repo>/sram_32x64/config_32x64_ss.py
# then copy build_ss/*_SS_1p6V_100C.lib into sram_32x64/sram_32x64_files/
# NOTE: num_threads/num_sim_threads assume this run gets the whole machine
# (16 cores) — set both to 8 if running the FF config at the same time.
word_size = 32
num_words = 64
write_size = 8
num_rw_ports = 1
num_r_ports = 1
num_w_ports = 0
words_per_row = 2

num_spare_cols = 0
num_spare_rows = 0

tech_name = "sky130"
process_corners = ["SS"]
supply_voltages = [1.60]
temperatures = [100]
nominal_corner_only = False

spice_name = "ngspice"

output_path = "build_ss"
output_name = "sky130_sram_256byte_1rw1r_32x64_8"

analytical_delay = False

num_threads = 16
num_sim_threads = 16
