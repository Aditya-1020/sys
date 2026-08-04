source $::env(SCRIPTS_DIR)/openroad/common/pdn_cfg.tcl

# macro connected to m2 power to cores met4 vertical
add_pdn_connect -grid macro -layers "met2 met4"