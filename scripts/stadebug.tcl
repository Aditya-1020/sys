source $::env(SCRIPTS_DIR)/openroad/common/io.tcl

set_cmd_units\
    -time ns\
    -capacitance pF\
    -current mA\
    -voltage V\
    -resistance kOhm\
    -distance um

set sta_report_default_digits 6

if { [namespace exists ::ord] } {
    # openroad --gui: full database with layout
    read_current_odb
    if { [catch { source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl } msg] } {
        puts "note: set_rc skipped ($msg)"
    }
    catch {
        if { [grt::have_routes] } {
            estimate_parasitics -global_routing
        } elseif { [est::check_corner_wire_cap] } {
            estimate_parasitics -placement
        }
    }
} else {
    # plain OpenSTA, same as the STAPostPNR step
    read_timing_info
}
read_spefs

foreach {corner_name corner_object} [lln::get_corner_dict] {
    lln::set_sta_cmd_corner $corner_name
    break
}

set ::_fields {slew cap input net fanout}

proc worst {{n 5}} {
    # n worst setup paths
    report_checks -sort_by_slack -path_delay max -fields $::_fields -group_path_count $n
}
proc worst_hold {{n 5}} {
    # n worst hold paths
    report_checks -sort_by_slack -path_delay min -fields $::_fields -group_path_count $n
}
proc slacks {} {
    # one-line health check: WNS setup / hold, TNS
    report_worst_slack -max
    report_worst_slack -min
    report_tns
}
proc to {pin {n 1}} {
    report_checks -to $pin -group_path_count $n -fields $::_fields
}
proc from {pin {n 1}} {
    report_checks -from $pin -group_path_count $n -fields $::_fields
}
proc between {a b} {
    report_checks -from $a -to $b -fields $::_fields
}
proc viol {} {
    report_check_types -violators -max_slew -max_capacitance -max_fanout
}
proc _violating_paths {delay} {
    set rows {}
    foreach path [find_timing_paths -path_delay $delay -sort_by_slack \
                      -unique_paths_to_endpoint -group_path_count 999999 -slack_max 0] {
        lappend rows [list [get_property $path slack] \
                           [get_property [get_property $path startpoint] full_name] \
                           [get_property [get_property $path endpoint] full_name]]
    }
    return [lsort -real -index 0 $rows]
}
proc vpaths {{n 20} {delay max}} {
    set rows [_violating_paths $delay]
    puts [format "%-14s %-26s %10s" Startpoint Endpoint Slack]
    foreach row [lrange $rows 0 [expr {$n - 1}]] {
        lassign $row slack start end
        puts [format "%-14s %-26s %10.4f" $start $end $slack]
    }
    puts "[llength $rows] violating paths ($delay)"
}
proc offenders {{n 20} {delay max}} {
    # violating endpoints tallied by startpoint, worst count first
    set tally [dict create]
    foreach row [_violating_paths $delay] { dict incr tally [lindex $row 1] }
    set rows {}
    dict for {start count} $tally { lappend rows [list $count $start] }
    foreach row [lrange [lsort -integer -index 0 -decreasing $rows] 0 [expr {$n - 1}]] {
        puts [format "%6dx  %s" {*}$row]
    }
}
proc clk_info {} {
    report_clock_properties
    report_clock_skew
}
proc cheat {} {
    puts {
── helpers ─────────────────────────────────────────────────────────────
  slacks              WNS setup/hold + TNS               worst ?n?     n worst setup paths
  worst_hold ?n?      n worst hold paths                 viol          slew/cap/fanout violators
  vpaths ?n? ?max|min?    violator table, worst first    offenders ?n?   startpoints by vio count
  to <pin> ?n?        paths ending at pin                from <pin> ?n?  paths starting at pin
  between <a> <b>     path a -> b                        clk_info      clocks + skew
  cheat               show this again
── the real commands the helpers wrap ──────────────────────────────────
  report_checks -sort_by_slack -path_delay max|min -group_path_count N
  report_checks -from _20522_/Q -to _20104_/D -fields {slew cap net fanout}
  report_checks -through [get_nets {some.hierarchical.net}]
  report_worst_slack -max | -min      report_tns / report_wns
  report_check_types -violators       check_setup -verbose
  report_clock_properties             report_clock_skew
  get_fanout -from <pin>              get_fanin -to <pin>
  get_pins/get_nets/get_cells <pattern>   (glob patterns allowed)
  report_power                        report_units
────────────────────────────────────────────────────────────────────────}
}

puts "loaded: $::env(DESIGN_NAME) @ $corner_name"
cheat
