# 512 B, 32-bit, dual-port to match sky130_sram_..._1rw1r and the in_fifo
word_size   = 32        # BITS (not bytes)
num_words   = 128       # 128 * 32b = 4096b = 512 bytes
write_size  = 8         # byte-write granularity -> matches the _8 macro

words_per_row   = 2          # 32 x 128 array
# "grid": route the internal supply grid but add NO perimeter ring.
# vccd1/vssd1 are left as distributed top-level pins for the parent chip's
# PDN to connect to (minimal area, powered from the SoC it integrates into).
# NOTE: "single" would give one pin per rail but is broken in this fork's
# gridless router (missing supply_router.get_ll_pin) -> do not use it.
supply_pin_type = "grid"

# dual-port 1rw1r  (the in_fifo writes port0 and reads port1 same cycle)
num_rw_ports = 1
num_r_ports  = 1
num_w_ports  = 0

tech_name        = "sky130"     # NOT scn4m_subm
process_corners  = ["TT"]
supply_voltages  = [1.8]        # sky130 nominal, not 3.3
temperatures     = [25]

output_path = "config2"
output_name = "sky130_sram_512byte_1rw1r_32x128_8"

# To force this to use magic and netgen for DRC/LVS/PEX
# drc_name = "magic"
# lvs_name = "netgen"
# pex_name = "magic"
