# Loaded by scripts/stadebug into `openroad`, `openroad -gui`, or `sta`.
#
# Unlike a LibreLane STA step -- which forks one process per corner and only
# ever holds one -- this loads every corner into a single session, so a bare
# report_checks/report_worst_slack answers across all of them at once and the
# per-corner helpers below can tabulate them side by side.
#
# The wrapper passes these in the environment:
#   SCRIPTS_DIR      librelane's scripts/ directory
#   _TCL_ENV_IN      the STA step's _env_*.tcl (io.tcl sources it)
#   _SDC_IN          constraints to read
#   _STA_CORNERS     corners to define, space separated
#   _STA_CMD_CORNER  corner that corner-less commands default to

source $::env(SCRIPTS_DIR)/openroad/common/io.tcl

set_cmd_units\
    -time ns\
    -capacitance pF\
    -current mA\
    -voltage V\
    -resistance kOhm\
    -distance um

set sta_report_default_digits 6

set ::_corners $::env(_STA_CORNERS)
set ::_fields {slew capacitance input_pin net fanout}

# LIB, CURRENT_SPEF and a macro's `lib` are all wildcard dicts keyed by corner
# pattern, e.g. {"*_tt_025C_1v80" /path/to.lib "*_ss_100C_1v60" ...}.
proc _by_corner {wildcard_dict corner} {
    set out [list]
    foreach {pattern value} $wildcard_dict {
        if { [string match $pattern $corner] } {
            lappend out $value
        }
    }
    return $out
}

proc _env_by_corner {var corner} {
    if { ![info exists ::env($var)] } {
        return [list]
    }
    return [_by_corner $::env($var) $corner]
}

proc _corner_libs {corner} {
    set libs [_env_by_corner LIB $corner]
    if { [info exists ::env(EXTRA_LIBS)] } {
        lappend libs {*}$::env(EXTRA_LIBS)
    }
    if { [info exists ::env(MACROS)] } {
        dict for {macro_name macro_data} $::env(MACROS) {
            if { [dict exists $macro_data lib] } {
                lappend libs {*}[_by_corner [dict get $macro_data lib] $corner]
            }
        }
    }
    return $libs
}

define_corners {*}$::_corners
foreach corner $::_corners {
    foreach lib [_corner_libs $corner] {
        puts "Reading '$corner' timing library at '$lib'…"
        read_liberty -corner $corner $lib
    }
}

# The .odb carries the LEFs and the placed/routed layout; only fall back to the
# netlist for pre-PnR steps or plain OpenSTA, which cannot read a database.
if { [namespace exists ::ord] && [info exists ::env(CURRENT_ODB)] && [file exists $::env(CURRENT_ODB)] } {
    puts "Reading OpenROAD database at '$::env(CURRENT_ODB)'…"
    read_db $::env(CURRENT_ODB)
    set_global_vars
} else {
    # openroad's read_verilog builds an odb block, so it needs a technology
    # first; plain OpenSTA has no database and must not be given LEFs.
    if { [namespace exists ::ord] } {
        read_lefs
    }
    puts "Reading top-level netlist at '$::env(CURRENT_NL)'…"
    read_verilog $::env(CURRENT_NL)
    link_design $::env(DESIGN_NAME)
    set_global_vars
}

read_current_sdc

set ::_spefs_read 0
foreach corner $::_corners {
    foreach spef [_env_by_corner CURRENT_SPEF $corner] {
        puts "Reading '$corner' parasitics at '$spef'…"
        read_spef -corner $corner $spef
        incr ::_spefs_read
    }
}

# No RCX output (pre-PnR / mid-PnR step): fall back to estimates so the corners
# still have parasitics, rather than reporting wireless delays.
if { $::_spefs_read == 0 && [namespace exists ::ord] } {
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
}

lln::set_sta_cmd_corner $::env(_STA_CMD_CORNER)
set ::_cmd_corner $::env(_STA_CMD_CORNER)

# ── per-corner helpers ──────────────────────────────────────────────────────
# Every reporting helper takes an optional trailing corner; omit it and OpenSTA
# reports the worst across all loaded corners.

proc _corner_arg {corner} {
    if { $corner eq "" } {
        return [list]
    }
    return [list -corner $corner]
}

proc corners {} {
    # loaded corners, active one marked
    foreach corner $::_corners {
        puts [format " %s %s" [expr {$corner eq $::_cmd_corner ? "*" : " "}] $corner]
    }
}

proc corner {{name ""}} {
    # get or set the corner that corner-less commands default to
    if { $name eq "" } {
        return $::_cmd_corner
    }
    if { [lsearch -exact $::_corners $name] == -1 } {
        error "corner '$name' is not loaded; see `corners`"
    }
    lln::set_sta_cmd_corner $name
    set ::_cmd_corner $name
    return $name
}

proc _corner_wns {corner delay} {
    set paths [find_timing_paths -corner $corner -path_delay $delay \
                   -sort_by_slack -group_path_count 1]
    if { [llength $paths] == 0 } {
        return ""
    }
    return [get_property [lindex $paths 0] slack]
}

proc _corner_violators {corner delay} {
    # returns: {slack startpoint endpoint} per violating endpoint, worst first
    set rows {}
    foreach path [find_timing_paths -corner $corner -path_delay $delay -sort_by_slack \
                      -unique_paths_to_endpoint -group_path_count 999999 -slack_max 0] {
        lappend rows [list [get_property $path slack] \
                           [get_property [get_property $path startpoint] full_name] \
                           [get_property [get_property $path endpoint] full_name]]
    }
    return [lsort -real -index 0 $rows]
}

proc slacks {} {
    # WNS setup/hold for every corner (one path per corner, so it is quick)
    puts [format "%-20s %12s %12s" corner setup hold]
    foreach corner $::_corners {
        puts [format "%-20s %12s %12s" $corner \
                  [_fmt_slack [_corner_wns $corner max]] \
                  [_fmt_slack [_corner_wns $corner min]]]
    }
}

proc summary {} {
    # WNS, TNS and violating-endpoint count per corner; walks every violator
    puts [format "%-20s %10s %10s %6s %10s %10s %6s" \
              corner setup-wns setup-tns n hold-wns hold-tns n]
    foreach corner $::_corners {
        set row [list $corner]
        foreach delay {max min} {
            set violators [_corner_violators $corner $delay]
            set tns 0.0
            foreach violator $violators {
                set tns [expr {$tns + [lindex $violator 0]}]
            }
            lappend row [_fmt_slack [_corner_wns $corner $delay]] \
                        [format "%.4f" $tns] [llength $violators]
        }
        puts [format "%-20s %10s %10s %6s %10s %10s %6s" {*}$row]
    }
}

proc _fmt_slack {slack} {
    if { $slack eq "" } {
        return "-"
    }
    return [format "%.4f" $slack]
}

proc worst {{n 5} {corner ""}} {
    # n worst setup paths
    report_checks -sort_by_slack -path_delay max -fields $::_fields \
        -group_path_count $n {*}[_corner_arg $corner]
}
proc worst_hold {{n 5} {corner ""}} {
    # n worst hold paths
    report_checks -sort_by_slack -path_delay min -fields $::_fields \
        -group_path_count $n {*}[_corner_arg $corner]
}
proc to {pin {n 1} {corner ""}} {
    report_checks -to $pin -group_path_count $n -fields $::_fields {*}[_corner_arg $corner]
}
proc from {pin {n 1} {corner ""}} {
    report_checks -from $pin -group_path_count $n -fields $::_fields {*}[_corner_arg $corner]
}
proc between {a b {corner ""}} {
    report_checks -from $a -to $b -fields $::_fields {*}[_corner_arg $corner]
}
proc across {pin {delay max}} {
    # slack of the worst path ending at pin, corner by corner
    puts [format "%-20s %12s" corner slack]
    foreach corner $::_corners {
        set paths [find_timing_paths -corner $corner -to $pin -path_delay $delay \
                       -sort_by_slack -group_path_count 1]
        set slack [expr {[llength $paths] ? [get_property [lindex $paths 0] slack] : ""}]
        puts [format "%-20s %12s" $corner [_fmt_slack $slack]]
    }
}
proc viol {{corner ""}} {
    report_check_types -violators -max_slew -max_capacitance -max_fanout \
        {*}[_corner_arg $corner]
}
proc vpaths {{n 20} {delay max} {corner ""}} {
    if { $corner eq "" } {
        set corner $::_cmd_corner
    }
    set rows [_corner_violators $corner $delay]
    puts [format "%-14s %-26s %10s" Startpoint Endpoint Slack]
    foreach row [lrange $rows 0 [expr {$n - 1}]] {
        lassign $row slack start end
        puts [format "%-14s %-26s %10.4f" $start $end $slack]
    }
    puts "[llength $rows] violating paths ($delay, $corner)"
}
proc offenders {{n 20} {delay max} {corner ""}} {
    # violating endpoints tallied by startpoint, worst count first
    if { $corner eq "" } {
        set corner $::_cmd_corner
    }
    set tally [dict create]
    foreach row [_corner_violators $corner $delay] { dict incr tally [lindex $row 1] }
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
── corners ─────────────────────────────────────────────────────────────
  corners             list loaded corners, * = active   corner <name>   set the active corner
  slacks              WNS setup/hold, every corner      summary         + TNS and violator counts
  across <pin>        worst path to pin, every corner
  Every helper below takes a trailing corner name; omit it and OpenSTA
  reports the worst across all corners at once.
── paths ───────────────────────────────────────────────────────────────
  worst ?n? ?corner?      n worst setup paths           worst_hold ?n? ?corner?   n worst hold paths
  viol ?corner?           slew/cap/fanout violators     vpaths ?n? ?max|min? ?corner?  violator table
  to <pin> ?n? ?corner?   paths ending at pin           from <pin> ?n? ?corner?   paths starting at pin
  between <a> <b>         path a -> b                   offenders ?n?   startpoints by vio count
  clk_info                clocks + skew                 cheat           show this again
── the real commands the helpers wrap ──────────────────────────────────
  report_checks -corner <c> -sort_by_slack -path_delay max|min -group_path_count N
  report_checks -from _20522_/Q -to _20104_/D -fields {slew capacitance net fanout}
  report_checks -through [get_nets {some.hierarchical.net}]
  report_worst_slack -max | -min      report_tns / report_wns
  report_check_types -violators       check_setup -verbose
  report_clock_properties             report_clock_skew
  get_fanout -from <pin>              get_fanin -to <pin>
  get_pins/get_nets/get_cells <pattern>   (glob patterns allowed)
  report_power                        report_units
────────────────────────────────────────────────────────────────────────}
}

puts "loaded: $::env(DESIGN_NAME), [llength $::_corners] corners, active $::_cmd_corner"
cheat
