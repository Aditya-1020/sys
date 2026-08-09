source $::env(SCRIPTS_DIR)/openroad/common/pdn_cfg.tcl

add_pdn_connect -grid macro -layers "met2 $::env(PDN_VERTICAL_LAYER)"