# Custom PDN configuration for SRAM macro integration
#
# Unified Parameter Matrix Configuration:
# - Top-level block power entry pins are on the Horizontal Layer Parameter.
# - $::env(PDN_HORIZONTAL_LAYER) -> Explicitly locked as horizontal (Metal5)
# - $::env(PDN_VERTICAL_LAYER)   -> Explicitly locked as vertical (Metal4)
# - $::env(PDN_RAIL_LAYER)       -> Mapped to standard cell rails (Metal1)
# - Macro internal structures    -> Terminate at Horizontal Metal3
#
# Based on librelane's default pdn_cfg.tcl.
source extra_config.tcl

source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections

# =============================================================================
# EXPLICIT TINY TAPEOUT TO IHP PDK NET BRIDGING
# =============================================================================
# 1. Connect standard logic cell rows to the TT Top-Level Nets
add_global_connection -net $::env(VDD_NET) -inst_pattern .* -pin_pattern {vdd|VDD|VPWR|vpwr}
add_global_connection -net $::env(GND_NET) -inst_pattern .* -pin_pattern {vss|VSS|VGND|vgnd}

# =============================================================================
set_voltage_domain -name CORE -power $::env(VDD_NET) -ground $::env(GND_NET) 

# =========================================================================
# STANDARD CELL POWER GRID CONFIGURATION
# =========================================================================
# Flipped Entry Matrix: Block-level entry pins reside on the Horizontal layer 
# parameter (Metal5), matching exactly where external power streams into the block canvas.

define_pdn_grid \
    -name stdcell_grid \
    -starts_with POWER \
    -voltage_domain CORE \
    -pins $::env(PDN_VERTICAL_LAYER)

add_pdn_stripe \
    -grid stdcell_grid \
    -layer $::env(PDN_VERTICAL_LAYER) \
    -width $::env(PDN_VWIDTH) \
    -pitch $::env(PDN_VPITCH) \
    -offset $::env(PDN_VOFFSET) \
    -spacing $::env(PDN_VSPACING) \
    -starts_with POWER -extend_to_core_ring

# 1. HORIZONTAL STRIPE LAYER: Explicitly forced to horizontal layout rules
add_pdn_stripe \
    -grid stdcell_grid \
    -layer $::env(PDN_HORIZONTAL_LAYER) \
    -width $::env(PDN_HWIDTH) \
    -pitch $::env(PDN_HPITCH) \
    -offset $::env(PDN_HOFFSET) \
    -spacing $::env(PDN_HSPACING) \
    -starts_with POWER

# 2. VERTICAL STRIPE LAYER: Explicitly forced to vertical layout rules
add_pdn_stripe \
    -grid stdcell_grid \
    -layer $::env(TILE_PDN_VERTICAL_LAYER) \
    -width $::env(TILE_PDN_VWIDTH) \
    -pitch $::env(TILE_PDN_VPITCH) \
    -offset $::env(TILE_PDN_VOFFSET) \
    -spacing $::env(TILE_PDN_VSPACING) \
    -starts_with POWER

# 3. Standard Cell Rails on Metal1
if { $::env(PDN_ENABLE_RAILS) == 1 } {
    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(PDN_RAIL_LAYER) \
        -width $::env(PDN_RAIL_WIDTH) \
        -followpins \
        -extend_to_core_ring

    # Connect horizontal Metal1 cell rails to the Vertical power straps (Metal4)
    add_pdn_connect \
        -grid stdcell_grid \
        -layers "$::env(PDN_RAIL_LAYER) $::env(PDN_VERTICAL_LAYER)"
}

# Connect core grid Vertical stripes to Horizontal stripes
add_pdn_connect \
    -grid stdcell_grid \
    -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

#add_pdn_connect \
    -grid stdcell_grid \
    -layers "$::env(PDN_HORIZONTAL_LAYER) TopMetal1" \
    -vias {TopVia1}

# =========================================================================
# SRAM MACRO POWER GRID CONNECTION
# =========================================================================
# Configures the macro-grid routine loop to capture your macro block boundaries.
# Steps down dynamically through the alternating parameters to reach the micro-core tracks.

define_pdn_grid \
    -macro \
    -default \
    -name macro \
    -starts_with POWER \
    -halo "$::env(PDN_HORIZONTAL_HALO) $::env(PDN_VERTICAL_HALO)" 

# Step 1: Connect Top-Level Horizontal Parameter pins down to the Vertical Parameter straps
#add_pdn_connect \
    -grid macro \
    -layers "TopMetal1 $::env(PDN_HORIZONTAL_LAYER)" \
    -vias {TopVia1}

add_pdn_connect \
    -grid macro \
    -layers "$::env(PDN_HORIZONTAL_LAYER) $::env(PDN_VERTICAL_LAYER)"

# Step 2: Connect Vertical Parameter straps straight down to the macro's true Horizontal Metal3 targets
add_pdn_connect \
    -grid macro \
    -layers "$::env(PDN_VERTICAL_LAYER) Metal3"
