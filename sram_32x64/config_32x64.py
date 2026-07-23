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
process_corners = ["FF", "TT", "SS"]
supply_voltages = [1.95, 1.80, 1.60]
temperatures = [-40, 25, 100]
nominal_corner_only = True

spice_name = "ngspice"

output_path = "build"
output_name = "sky130_sram_256byte_1rw1r_32x64_8"

analytical_delay = False

num_threads = 4
num_sim_threads = 4