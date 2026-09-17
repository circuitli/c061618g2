# Copyright 2026 circuitli (https://github.com)
# 
# Licensed under the CERN Open Hardware Licence Version 2 - Weakly Reciprocal (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://cern-ohl.web.cern.ch/
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Connect OpenLane's global standard nets directly to the primary domain
set_voltage_domain -name CORE -power $::env(VDD_NET) -ground $::env(GND_NET)

# =============================================================================
# GLOBAL NET STRIP LOGIC (FOR IHP SUBSTRATE WELL PASSING)
# =============================================================================
add_global_connection -net $::env(VDD_NET) -inst_pattern .* -pin_pattern {VDD|vdd}
add_global_connection -net $::env(GND_NET) -inst_pattern .* -pin_pattern {VSS|vss}
# =============================================================================

# =============================================================================
# DYNAMIC TECHNOLOGY GRID EXTRACTION
# =============================================================================
set db_block         [ord::get_db_block]
set db_tech          [ord::get_db_tech]
set db_units         [$db_tech getDbUnitsPerMicron]

# 1. Extract the physical hard boundaries of your macro canvas
set core_box  [$db_block getDieArea]
set core_left [expr {double([$core_box xMin]) / $db_units}]

# =============================================================================
# DYNAMIC CENTER-LINE EXTRACTION (PARSER SYNTAX BALANCED)
# =============================================================================
set core_ymin [expr {double([$core_box yMin]) / double($db_units)}]
set core_ymax [expr {double([$core_box yMax]) / double($db_units)}]

# Double check that both braces and parentheses close cleanly here
set calculated_h_offset [expr {($core_ymin + $core_ymax) / 2.0}]
# =============================================================================

# 2. Query the verified layout rail width from OpenLane
set native_pdk_width $::env(PDN_RAIL_WIDTH)

# 3. Dynamically extract standard cell row spacing directly from the live layout
set first_layout_row [lindex [$db_block getRows] 0]
set row_site_object  [$first_layout_row getSite]
set calculated_rail_pitch [expr {double([$row_site_object getHeight]) / $db_units}]

# 4. COMPLIANT ACCURACY EXTRACTION: Read the exact Y-center of the first layout track
set physical_inst     [lindex [$db_block getInsts] 0]
set physical_bbox     [$physical_inst getBBox]
set physical_y_center [expr {(double([$physical_bbox yMin]) + double([$physical_bbox yMax])) / 2.0 / $db_units}]
# =============================================================================

# Safely initialize your custom grid name to bypass the memory crash
define_pdn_grid \
    -name  stdcell_grid \
    -starts_with POWER \
    -voltage_domain CORE \
    -pins "$::env(PDN_HORIZONTAL_LAYER)" 

# Set core_offsets to 0 so the ring sits flush against 
# the boundary walls, leaving full internal track clearance for the cell rails!
#add_pdn_ring \
    -grid stdcell_grid \
    -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)" \
    -widths "$::env(PDN_VWIDTH) $::env(PDN_HWIDTH)" \
    -spacings "$::env(PDN_VSPACING) $::env(PDN_HSPACING)" \
    -core_offsets "0.72"

# 2. Standard Cell Rails on Metal1
if { $::env(PDN_ENABLE_RAILS) == 1 } {
    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(PDN_RAIL_LAYER) \
        -width $::env(PDN_RAIL_WIDTH) \
        -followpins

    # Connect horizontal Metal1 cell rails to the Vertical power straps (Metal4)
    add_pdn_connect \
        -grid stdcell_grid \
        -layers "$::env(PDN_RAIL_LAYER) $::env(PDN_VERTICAL_LAYER)"
}
# =============================================================================

# 1. Unified Vertical Stripes -> EXTEND_TO_BOUNDARY
add_pdn_stripe -grid stdcell_grid \
               -layer $::env(PDN_VERTICAL_LAYER) \
               -width $::env(PDN_VWIDTH) \
               -pitch $::env(PDN_VPITCH) \
               -offset $::env(PDN_VOFFSET) \
               -spacing $::env(PDN_VSPACING) 

# 3. Horizontal Mesh Power Landing Pads -> EXTEND_TO_BOUNDARY
add_pdn_stripe -grid stdcell_grid \
               -layer $::env(PDN_HORIZONTAL_LAYER) \
               -width $::env(PDN_HWIDTH) \
               -pitch $::env(PDN_HPITCH) \
               -offset $::env(PDN_HOFFSET) \
               -spacing $::env(PDN_HSPACING) \
               -nets "$::env(VDD_NET) $::env(GND_NET)" 

# 4. Connect the layers cleanly together via native layer connectivity strings
#add_pdn_connect -grid stdcell_grid -layers "$::env(PDN_HORIZONTAL_LAYER) Metal2"
add_pdn_connect -grid stdcell_grid -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

# Compliance macro integration grid
#define_pdn_grid -macro -default -name macro_grid -starts_with GROUND
#add_pdn_connect -grid macro_grid -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

#pdngen -skip_trim