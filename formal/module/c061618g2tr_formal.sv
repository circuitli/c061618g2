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

`ifndef C061618G2_FORMAL_SV
`define C061618G2_FORMAL_SV

`include "src/module/c061618gtr.v"

`include "formal/core/c061618g2_formal.sv"

`default_nettype none

// =========================================================================
// FORMAL VERIFICATION PROPERTIES MODULE FOR TMR VOTER
// =========================================================================
module c061618g2tr_formal (
    input  wire [7:0] ui_in,
    input  wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    input  wire [7:0] uio_out,
    input  wire [7:0] uio_oe,
    input  wire [0:0] ena,
    input  wire [0:0] clk,
    input  wire [0:0] rst_n,
    
    // Exposed internal intermediate nets via bind mapping
    input  wire [7:0] uo_out1,  uo_out2,  uo_out3,
    input  wire [7:0] uio_out1, uio_out2, uio_out3,
    input  wire [7:0] uio_oe1,  uio_oe2,  uio_oe3
);

    // -------------------------------------------------------------------------
    // 1. COMBINATIONAL ASSERTIONS: CORE TMR MATHEMATICAL PROOFS
    // -------------------------------------------------------------------------
    
    // Dedicated hardware output voter verification
    assert_uo_out_voting: assert property (
        @(posedge clk) (uo_out == ((uo_out1 & uo_out2) | (uo_out2 & uo_out3) | (uo_out1 & uo_out3)))
    );

    // Bidirectional output network voter verification
    assert_uio_out_voting: assert property (
        @(posedge clk) (uio_out == ((uio_out1 & uio_out2) | (uio_out2 & uio_out3) | (uio_out1 & uio_out3)))
    );

    // Output enablement bus voter verification
    assert_uio_oe_voting: assert property (
        @(posedge clk) (uio_oe == ((uio_oe1 & uio_oe2) | (uio_oe2 & uio_oe3) | (uio_oe1 & uio_oe3)))
    );

    // -------------------------------------------------------------------------
    // 2. FAULT TOLERANCE CHARACTERISTICS: SINGLE PROJECT DOMAIN FAULT IMMUNITY
    // -------------------------------------------------------------------------
    
    // Proof: If domain 2 and domain 3 agree, an arbitrary fault on domain 1 is filtered out completely
    assert_domain1_fault_masked: assert property (
        @(posedge clk) ((uo_out2 == uo_out3) && (uio_out2 == uio_out3) && (uio_oe2 == uio_oe3)) -> 
                       ((uo_out == uo_out2) && (uio_out == uio_out2) && (uio_oe == uio_oe2))
    );

    // Proof: If domain 1 and domain 3 agree, an arbitrary fault on domain 2 is filtered out completely
    assert_domain2_fault_masked: assert property (
        @(posedge clk) ((uo_out1 == uo_out3) && (uio_out1 == uio_out3) && (uio_oe1 == uio_oe3)) -> 
                       ((uo_out == uo_out1) && (uio_out == uio_out1) && (uio_oe == uio_oe1))
    );

    // Proof: If domain 1 and domain 2 agree, an arbitrary fault on domain 3 is filtered out completely
    assert_domain3_fault_masked: assert property (
        @(posedge clk) ((uo_out1 == uo_out2) && (uio_out1 == uio_out2) && (uio_oe1 == uio_oe2)) -> 
                       ((uo_out == uo_out1) && (uio_out == uio_out1) && (uio_oe == uio_oe1))
    );

endmodule


// =========================================================================
// SYSTEMVERILOG BIND INJECTION TARGET FILE
// =========================================================================
bind c061618g2tr c061618g2tr_formal i_c061618g2tr_formal (
    .ui_in    (ui_in),
    .uo_out   (uo_out),
    .uio_in   (uio_in),
    .uio_out  (uio_out),
    .uio_oe   (uio_oe),
    .ena      (ena),
    .clk      (clk),
    .rst_n    (rst_n),
    
    // Binding the parent module's internal tracking wires down into the checker
    .uo_out1  (uo_out1),
    .uo_out2  (uo_out2),
    .uo_out3  (uo_out3),
    .uio_out1 (uio_out1),
    .uio_out2 (uio_out2),
    .uio_out3 (uio_out3),
    .uio_oe1  (uio_oe1),
    .uio_oe2  (uio_oe2),
    .uio_oe3  (uio_oe3)
);

`default_nettype wire
`endif // C061618G2TR_FORMAL_SV