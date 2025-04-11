/* verilator lint_off STMTDLY */
module testbench_fma16;
  logic        clk, reset, on1;
  logic [15:0] x, y, z, rexpected, result;
  logic [7:0]  ctrl;
  logic        mul, add, negp, negz;
  logic [1:0]  roundmode;
  logic [31:0] vectornum, errors;
  logic [63:0] totalTests;
  logic [75:0] testvectors1[30000:0];
  logic [75:0] testvectors2[300000:0];
  logic [3:0]  flags, flagsexpected; // Invalid, Overflow, Underflow, Inexact

  // instantiate device under test
  fma16 dut(x, y, z, mul, add, negp, negz, roundmode, result, flags);

  // generate clock
  always 
    begin
      clk = 1; #5; clk = 0; #5;
    end

  // at start of test, load vectors and pulse reset
  initial
    begin
      $readmemh("work/fma_2.tv", testvectors1);
      $readmemh("work/fma_special_rz.tv", testvectors2);
      vectornum = 0; errors = 0;
      reset = 1; #22; reset = 0;
      on1 = 1;
    end

  // apply test vectors on rising edge of clk
  always @(posedge clk)
    begin
      if (on1) begin
        #1; {x, y, z, ctrl, rexpected, flagsexpected} = testvectors1[vectornum];
        {roundmode, mul, add, negp, negz} = ctrl[5:0];
        // if (testvectors1[vectornum] === 'x) begin
        //   on1 = 0;
        //   totalTests = vectornum;
        //   vectornum = 0;
        //   reset = 1; #22; reset = 0;
        // end else begin
        //   on1 = 1;
        //   totalTests = totalTests;
        //   vectornum = vectornum;
        //   reset = 0;
        // end
      end else begin
        #1; {x, y, z, ctrl, rexpected, flagsexpected} = testvectors2[vectornum];
        {roundmode, mul, add, negp, negz} = ctrl[5:0];
        // on1 = 0;
        // totalTests = totalTests;
        // vectornum = vectornum;
        // reset = 0;
      end
    end

  // check results on falling edge of clk
  always @(negedge clk)
    if (~reset) begin // skip during reset
      if (result !== rexpected /* | flags !== flagsexpected */) begin  // check result
        $display("Error: inputs %h * %h + %h control: ", x, y, z, ctrl);
        $display("  result = %h (%h expected) flags = %b (%b expected)", 
          result, rexpected, flags, flagsexpected);
        $display("negp negz: %h %h", dut.negp, dut.negz);
        $display("x: %h", dut.correctedX);
        $display("y: %h", dut.correctedY);
        $display("z: %h", dut.correctedZ);
        $display("normals: %h %h %h", dut.xNormal, dut.yNormal, dut.zNormal);
        $display("sum: %h", dut.addUnit.sum);
        $display("mof: %h", dut.mulOverflow);
        $display("aof: %h", dut.addOverflow);
        $display("muf: %h", dut.mulUnderflow);
        $display("ex: %h", dut.mulEx);
        $display("offset: %h", dut.addUnit.offset);
        $display("exI: %h", dut.addUnit.exponentIntermed);
        $display("alignedP: %h", dut.expandedProduct);
        $display("alignedZ: %h", dut.alignedZ);
        $display("tempfrac: %h", dut.tempFrac);
        $display("nx: %h", {{1{1'b1}}, dut.correctedX[9:0]});
        $display("ny: %h", {{1{1'b1}}, dut.correctedY[9:0]});
        $display("ssum: %h", dut.addUnit.sumShifted);
        $display("alc: %h", dut.addSetup.alignCount);
        $display("tempex: %h", dut.mulUnit.tempEx);
        $display("fmaex: %h", dut.fmaEx);
        $display("znex: %h", dut.xNonInf);
        errors = errors + 1;
      end
      vectornum = vectornum + 1;
      if ((on1) & (testvectors1[vectornum] === 'x)) begin
        on1 = 0;
        totalTests = vectornum;
        vectornum = 0;
        reset = 1; #22; reset = 0;
      end
      if ((!on1) & (testvectors2[vectornum] === 'x)) begin 
        $display("%d tests completed with %d errors", 
	           totalTests + vectornum - 2, errors);
        $stop;
      end
    end
endmodule
