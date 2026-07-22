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
process_corners = ["TT"]
supply_voltages = [1.8]
temperatures = [25]

output_path = "build"
output_name = "sky130_sram_256byte_1rw1r_32x64_8"

analytical_delay = True
check_lvsdrc = False