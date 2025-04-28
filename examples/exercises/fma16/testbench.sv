/* verilator lint_off STMTDLY */
module testbench_fma16;
  logic        clk, reset;
  logic [15:0] x, y, z, rexpected, result;
  logic [7:0]  ctrl;
  logic        mul, add, negp, negz;
  logic [1:0]  roundmode;
  logic [31:0] vectornum, errors;
  logic [75:0] testvectors[1000000:0];
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
      // $readmemh("tests2/fmul_0.tv", testvectors);
      // $readmemh("tests2/fadd_0.tv", testvectors);
      // $readmemh("tests2/fma_0.tv", testvectors);
      $readmemh("tests2/fma_special_rne.tv", testvectors);
      // $readmemh("tests2/baby_torture.tv", testvectors);
      // $readmemh("tests/fma_mega.tv", testvectors);
      // $readmemh("work/fma_rand_all.tv", testvectors);
      vectornum = 0; errors = 0;
      reset = 1; #22; reset = 0; 
    end

  // apply test vectors on rising edge of clk
  always @(posedge clk)
    begin
      #1; {x, y, z, ctrl, rexpected, flagsexpected} = testvectors[vectornum];
      {roundmode, mul, add, negp, negz} = ctrl[5:0];
    end

  // check results on falling edge of clk
  always @(negedge clk)
    if (~reset) begin // skip during reset
      // if (result !== rexpected /*| flags !== flagsexpected*/) begin  // check result
      if (result !== rexpected | flags !== flagsexpected) begin  // check result
        $display("Error: inputs %h * %h + %h  control: %h", x, y, z, ctrl);
        $display("  result = %h (%h expected) flags = %b (%b expected)", 
          result, rexpected, flags, flagsexpected);
        errors = errors + 1;
        $display("m a np nz: %h %h %h %h", dut.mul, dut.add, dut.negp, dut.negz);
        $display("rm: %b", dut.roundmode);
        $display("x, y, z: %h %h %h", dut.correctedX, dut.correctedY, dut.correctedZ);
        $display("norm, nan: %h %h", dut.allNormal, dut.noNans);
        $display("xyzni: %h %h %h", dut.xNonInf, dut.yNonInf, dut.zNonInf);
        $display("xyznz: %h %h %h", dut.xNonZero, dut.yNonZero, dut.zNonZero);
        $display("prod: %h", {dut.mulSign, dut.roundedMulEx, dut.mulFrac});
        $display("tf: %h", dut.fullMulFrac);
        $display("moui: %h %h %h", dut.mulOverflow, dut.mulUnderflow, dut.mulInexact);
        $display("p: %h", dut.expandedProduct);
        $display("z: %h", dut.alignedZ);
        $display("aligc: %h", dut.addSetup.alignCount);
        $display("sum: %h", dut.addUnit.sum);
        $display("sz: %h", dut.sumZero);
        $display("of: %h", dut.resultSelect.overflow);
        $display("exi: %h", dut.addUnit.exponentIntermed);
        $display("a grt: %h", dut.addUnit.addRounder.g, dut.addUnit.addRounder.r, dut.addUnit.addRounder.t);
        $display("ssub: %h", dut.addUnit.subnorm);
        $display("aex: %h", dut.addUnit.ex);
        $display("afrac: %h", dut.addUnit.frac);
      end
      vectornum = vectornum + 1;
      if (testvectors[vectornum] === 'x) begin 
        $display("%d tests completed with %d errors", 
	           vectornum, errors);
        $stop;
      end
    end
endmodule