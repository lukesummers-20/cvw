///////////////////////////////////////////
// icache.sv
//
// Written: jaallen@g.hmc.edu 2021-03-02
// Modified: 
//
// Purpose: Cache instructions for the ifu so it can access memory less often, saving cycles
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

`include "wally-config.vh"

module icache(
  // Basic pipeline stuff
  input logic 		   clk, reset,
  input logic 		   StallF, StallD,
  input logic 		   FlushD,
  input logic [`XLEN-1:0]  PCNextF,
  input logic [`XLEN-1:0]  PCPF,	      
  // Data read in from the ebu unit
  input logic [`XLEN-1:0]  InstrInF,
  input logic 		   InstrAckF,
  // Read requested from the ebu unit
  output logic [`XLEN-1:0] InstrPAdrF,
  output logic 		   InstrReadF,
  // High if the instruction currently in the fetch stage is compressed
  output logic 		   CompressedF,
  // High if the icache is requesting a stall
  output logic 		   ICacheStallF,
  // The raw (not decompressed) instruction that was requested
  // If this instruction is compressed, upper 16 bits may be the next 16 bits or may be zeros
  output logic [31:0] 	   InstrRawD
);

    // Configuration parameters
    // TODO Move these to a config file
    localparam integer BLOCKLEN = 256;
    localparam integer NUMLINES = 512;

    // Input signals to cache memory
    logic                       FlushMem;
    logic                       ICacheMemWriteEnable;
    logic [BLOCKLEN-1:0]  ICacheMemWriteData;
    logic                       EndFetchState;
    logic [`XLEN-1:0]           PCTagF, PCNextIndexF;  
    // Output signals from cache memory
    logic [31:0]   ICacheMemReadData;
    logic               ICacheMemReadValid;
  logic 		ICacheReadEn;
  
  ICacheMem #(.BLOCKLEN(BLOCKLEN), .NUMLINES(NUMLINES)) 
  cachemem(
        .*,
        // Stall it if the pipeline is stalled, unless we're stalling it and we're ending our stall
        .flush(FlushMem),
        .WriteEnable(ICacheMemWriteEnable),
        .WriteLine(ICacheMemWriteData),
        .DataWord(ICacheMemReadData),
        .DataValid(ICacheMemReadValid)
    );

    ICacheCntrl #(.BLOCKLEN(BLOCKLEN)) controller(.*);

    // For now, assume no writes to executable memory
    assign FlushMem = 1'b0;
endmodule

