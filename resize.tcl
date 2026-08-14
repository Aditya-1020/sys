source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
source $::env(SCRIPTS_DIR)/openroad/common/resizer.tcl

read_current_odb

puts "=== SRAM DIN DRIVER RESIZE ==="

set from_cell sky130_fd_sc_hd__dfxtp_2
set to_cell sky130_fd_sc_hd__dfxtp_4

set master [$::db findMaster $to_cell]
if {$master == "NULL"} {
    error "LEF master '$to_cell' not found"
}

set resized 0
foreach net [$::block getNets] {
    set net_name [$net getName]
    if {![string match {u_sram.dma_wdata_r*} $net_name]} {
        continue
    }

    foreach iterm [$net getITerms] {
        if {[$iterm getIoType] != "OUTPUT"} {
            continue
        }

        set inst [$iterm getInst]
        set inst_name [$inst getName]
        set ref [[$inst getMaster] getName]
        if {$ref != $from_cell} {
            puts "SKIP: $inst_name on $net_name is $ref (expected $from_cell)"
            continue
        }

        puts "RESIZE: $inst_name on $net_name ($ref) -> $to_cell"
        $inst swapMaster $master
        incr resized
    }
}

if {$resized == 0} {
    puts "WARN: no SRAM DIN drivers matched '$from_cell' on u_sram.dma_wdata_r* nets"
} else {
    puts "Upsized $resized SRAM DIN driver(s)"
}

source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
estimate_parasitics -placement

puts "=== SRAM DIN DRIVER RESIZE DONE ==="

write_views
