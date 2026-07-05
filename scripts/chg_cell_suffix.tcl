set cell_name "sky130_fd_sc_hd__a2111oi_0"
set new_cell_name "sky130_fd_sc_hd__a2111oi_4"

set infile "synth_out_pe.v"
set outfile "synth_out_pe_modified.v"

set in [open $infile r]
set out [open $outfile w]

while {[gets $in line] >= 0} {
    puts $out [string map [list $cell_name $new_cell_name] $line]
}

close $in
close $out

puts "Replaced '$cell_name' with '$new_cell_name' in $outfile"