# stadebug.tcl — bootstrap for an interactive STA session.
# Mirrors the setup preamble of librelane/scripts/openroad/sta/corner.tcl
# (everything before the canned report dump), then defines a few helper
# commands and hands over the prompt. Launched by scripts/stadebug, which
# reconstructs the environment this expects.

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

# ---------------------------------------------------------------------------
# helper commands (thin wrappers over report_checks and friends)
# ---------------------------------------------------------------------------
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
    # paths ending at a pin/register, e.g.:  to _20104_/D
    report_checks -to $pin -group_path_count $n -fields $::_fields
}
proc from {pin {n 1}} {
    # paths starting at a pin/register, e.g.:  from _20522_/Q
    report_checks -from $pin -group_path_count $n -fields $::_fields
}
proc between {a b} {
    # path between two points, e.g.:  between _20522_/Q _20104_/D
    report_checks -from $a -to $b -fields $::_fields
}
proc viol {} {
    # slew / cap / fanout violators
    report_check_types -violators -max_slew -max_capacitance -max_fanout
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
