# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for version 2020.2 of Vivado (or later)
if { [VersionCheck 2020.2] < 0 } {exit -1}

# Load base sub-modules
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/lcls-timing-core
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/axi-pcie-core/hardware/SlacPgpCardG3

# Load the lcls2-pgp-fw-lib source code
loadSource -lib lcls2_pgp_fw_lib -path "$::env(PROJ_DIR)/../../submodules/lcls2-pgp-fw-lib/shared/rtl/PgpLaneRx.vhd"
loadSource -lib lcls2_pgp_fw_lib -path "$::env(PROJ_DIR)/../../submodules/lcls2-pgp-fw-lib/shared/rtl/PgpLaneTx.vhd"
loadSource -lib lcls2_pgp_fw_lib -path "$::env(PROJ_DIR)/../../submodules/lcls2-pgp-fw-lib/shared/rtl/TimingPhyMonitor.vhd"

# Load the l2si-core source code
loadSource -lib l2si_core -dir "$::env(PROJ_DIR)/../../submodules/l2si-core/xpm/rtl"
loadSource -lib l2si_core -dir "$::env(PROJ_DIR)/../../submodules/l2si-core/base/rtl"

# Load common source code
loadRuckusTcl $::env(PROJ_DIR)/../../common

# Load local source Code
loadSource      -dir  "$::DIR_PATH/hdl"
loadConstraints -dir  "$::DIR_PATH/hdl"
loadConstraints -dir  "$::DIR_PATH/../ClinkSlacPgpCardG3Pgp4Lcls2Only/hdl"
loadSource      -path "$::DIR_PATH/../ClinkSlacPgpCardG3Pgp4Lcls2Only/hdl/SlacPgpCardG3Hsio.vhd"
loadSource      -path "$::DIR_PATH/../ClinkSlacPgpCardG3Pgp4Lcls2Only/hdl/Pgp4Lane.vhd"
loadSource      -path "$::DIR_PATH/../ClinkSlacPgpCardG3Pgp4Lcls2Only/hdl/TimingRx.vhd"

# Updating impl_1 strategy
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
