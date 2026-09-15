/*
 * Copyright 2026 circuitli (https://github.com)
 *
 * Licensed under the CERN Open Hardware Licence Version 2 - Weakly Reciprocal (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://cern-ohl.web.cern.ch/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
`ifndef TT_UM_C061618G2TR_V
`define TT_UM_C061618G2TR_V

// =========================================================================
// CONDITIONAL PDK INTERFACE RESOLUTION
// If compiling for physical synthesis (OpenLane/Yosys), hide the source file 
// so the tool treats the block as a clean hard macro blackbox.
// If compiling for local verification (Cocotb/Icarus), include the source
// so the simulator doesn't throw an 'Unknown module type' crash.
// =========================================================================
`include "src/module/c061618g2tr.v"

`default_nettype none

module tt_um_c061618g2tr (
    input  wire [7:0] ui_in,    // Dedicated hardware inputs
    output wire [7:0] uo_out,   // Dedicated hardware outputs
    input  wire [7:0] uio_in,   // Bidirectional bus input network
    (* keep = "true" *) output wire [7:0] uio_out,  // Bidirectional bus output network
    (* keep = "true" *) output wire [7:0] uio_oe,   // Safe output enablement bus mapping
    input  wire [0:0] ena,      // Tiny Tapeout macro block enable signal
    input  wire [0:0] clk,      // System clock injected for wrapper compliance
    input  wire [0:0] rst_n     // Active-low system reset
);

    // =========================================================================
    // 2. CORE HIERARCHICAL INSTANTIATION
    // =========================================================================
    (* keep_hierarchy = "TRUE" *) 
    c061618g2tr u_c061618g2tr (
        .clk     (clk),
        .rst_n   (rst_n),
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena)
    );

endmodule

`default_nettype wire
`endif
