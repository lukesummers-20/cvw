///////////////////////////////////////////
// mul.sv
//
// Written: David_Harris@hmc.edu 16 February 2021
// Modified: 
//
// Purpose: Integer multiplication
// 
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
// 
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module mul #(parameter XLEN) (
  input  logic                clk, reset,
  input  logic                StallM, FlushM,
  input  logic [XLEN-1:0]     ForwardedSrcAE, ForwardedSrcBE, // source A and B from after Forwarding mux
  input  logic [2:0]          Funct3E,                        // type of multiply
  output logic [XLEN*2-1:0]   ProdM                           // double-widthproduct
);

    logic [XLEN*2-1:0]  PP1M, PP2M, PP3M, PP4M;               // registered partial proudcts
 
  //////////////////////////////
  // Execute Stage: Compute partial products
  //////////////////////////////
    logic [XLEN*2-1:0] PP1E, PP2E, PP3E, PP4E;
    logic [XLEN-2:0] PA, PB;
    logic Pm;
    assign PP1E = ForwardedSrcAE[XLEN-2:0] * ForwardedSrcBE[XLEN-2:0];
    assign PA = ForwardedSrcBE[XLEN-1] * ForwardedSrcAE[XLEN-2:0];
    assign PB = ForwardedSrcAE[XLEN-1] * ForwardedSrcBE[XLEN-2:0];
    assign PP2E = {{2{1'b0}}, Funct3E == 3'b001 ? ~PA : PA, {XLEN-1{1'b0}}};
    assign PP3E = {{2{1'b0}}, ((Funct3E == 3'b011) | (Funct3E == 3'b000)) ?  PB : ~PB, {XLEN-1{1'b0}}};
    assign Pm = ForwardedSrcAE[XLEN-1] * ForwardedSrcBE[XLEN-1];
    always_comb begin
      case(Funct3E[1:0])
        2'b01: PP4E = {1'b1, Pm, {XLEN-3{1'b0}}, 1'b1, {XLEN{1'b0}}};
        2'b10: PP4E = {1'b1, ~Pm, {XLEN-2{1'b0}}, 1'b1, {XLEN-1{1'b0}}};
        2'b11: PP4E = {1'b0, Pm, {XLEN*2-2{1'b0}}};
        default: PP4E = {XLEN*2{1'b0}};
      endcase
    end
    
  // Memory Stage: Sum partial proudcts
  //////////////////////////////

  flopenrc #(XLEN*2) PP1Reg(clk, reset, FlushM, ~StallM, PP1E, PP1M); 
  flopenrc #(XLEN*2) PP2Reg(clk, reset, FlushM, ~StallM, PP2E, PP2M); 
  flopenrc #(XLEN*2) PP3Reg(clk, reset, FlushM, ~StallM, PP3E, PP3M); 
  flopenrc #(XLEN*2) PP4Reg(clk, reset, FlushM, ~StallM, PP4E, PP4M); 

  // add up partial products; this multi-input add implies CSAs and a final CPA
  assign ProdM = PP1M + PP2M + PP3M + PP4M; //ForwardedSrcAE * ForwardedSrcBE;
 endmodule
