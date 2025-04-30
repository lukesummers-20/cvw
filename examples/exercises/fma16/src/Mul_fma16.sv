// Luke Summers lsummers@g.hmc.edu 23 April 2025
// fma16 multiplication unit
// inputs:  xNonZero, yNonZero - 0 if input 0, 1 otherwise
//          xNonInf, yNonInf - 0 if input inf, 1 otherwise
//          add, roundmode - fma control signals
//          x, y - fma inputs {sign[15], ex[14:10], frac[9:0]}
// outputs: sign - product sign
//          roundedEx, unroundedEx - rounded and unrounded product exponent
//          frac - 10 bit product fraction
//          fullFrac - full 22 bit product, 2.22
//          underflow - 1 if underflow occurred, 0 otherwise
//          overflow - 1 if overflow occurred, 0 otherwise
//          inexact - 1 if inexact result, 0 otherwise
//          rAndT - 1 if all bits after gaurd bit in product are 1, 0 otherwise
module Mul_fma16(
    input  logic xNonZero, yNonZero, xNonInf, yNonInf, add,
    input  logic [1:0] roundmode,
    input  logic [15:0] x, y,
    output logic sign,
    output logic [4:0] roundedEx, unroundedEx,
    output logic [9:0] frac,
    output logic [21:0] fullFrac,
    output logic underflow, overflow , inexact, rAndT, g, rt
);
    // exponent logic intermed
    logic [5:0] tempEx;
    //rounding bits
    logic r, t, tAnd;
    // pre rounding frac
    logic [9:0] unroundedFrac;
    always_comb begin
        // sign bit
        sign = x[15] ^ y[15];
        // product, Q2.22 number
        fullFrac = {xNonZero, x[9:0]} * {yNonZero, y[9:0]};
        // product exponent, adjust for bias and if multiplication caused increase
        tempEx = {{1{1'b0}}, x[14:10]} + {{1{1'b0}}, y[14:10]} + {{5{1'b0}}, fullFrac[21]} - 15;
        if (tempEx[5] | (tempEx == 6'b011111)) begin
            // overflow and underflow
            if ((tempEx[4:0] < x[14:10]) | (tempEx == 6'b011111)) begin 
                // overflow
                underflow = 1'b0;
                overflow = 1'b1;
                // set tempEx so ex will be the number mul overflowed by
                tempEx = tempEx + 1;
            end else begin
                // underflow
                underflow = 1'b1;
                overflow = 1'b0;
                // set tempEx so ex will be the number mul underflowed by
                tempEx = ~tempEx + 1;
            end
        end else begin 
            // no underflow or overflow
            underflow = 1'b0;
            overflow = 1'b0;
        end
        // setting product exponent
        unroundedEx = tempEx[4:0];
        if (fullFrac[21]) begin
            // bit 21 set, so prod frac starts at bit 20
            unroundedFrac = fullFrac[20:11];
            // rounding bits
            g = fullFrac[10];
            r = fullFrac[9];
            t = |fullFrac[8:0];
            tAnd = &fullFrac[8:0];
        end else begin
            // bit 21 not set, so prod frac starts at bit 19
            unroundedFrac = fullFrac[19:10];
            // rounding bits
            g = fullFrac[9];
            r = fullFrac[8];
            t = |fullFrac[7:0];
            tAnd = &fullFrac[7:0];
        end
        // inexact flag for mul
        inexact = r | g | t | overflow ;
        // 1 if all bits after g are 1, 0 otherwise
        rAndT = r & tAnd;
        rt = r| t;
    end
    // rounding unit
    Round_fma16 mulRounder(
        .roundmode(roundmode),
        .sign(sign), .g(g), .r(r), .t(t),
        .fracIn(unroundedFrac), .exIn(unroundedEx),
        .fracOut(frac), .exOut(roundedEx)
    );
endmodule