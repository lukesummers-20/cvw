// Luke Summers
// fma16 multiplication unit
// ful product in tempFrac, 10 bit frac in frac

module Mul_fma16(
    input  logic xNonZero, yNonZero,
    input  logic [15:0] x, y,
    output logic sign,
    output logic [4:0] ex,
    output logic [9:0] frac,
    output logic [21:0] tempFrac,
    output logic underflow, overflow
);
    // exponent logic intermed
    logic [5:0] tempEx;

    assign sign = x[15] ^ y[15];

    assign tempFrac = {xNonZero, x[9:0]} * {yNonZero, y[9:0]};

    // tempFrac is 2.22, so frac depends on where first 1 in tempFrac is
    assign frac = tempFrac[21]? tempFrac[20:11] : tempFrac[19:10];

    // bias is 15, need to adjust if tempFrac[21] is 1 as that means tempFrac was not naturalized
    assign tempEx = x[14:10] + y[14:10] - 15 + {{4{1'b0}}, tempFrac[21]};

    // if tempEx[5] is set, it went negative so ex got too small
    assign underflow = tempEx[5];

    // if tempEx[5] is set and ex < x[14:10], bit got set from adding the exponents together
    // not from becoming negative
    // also if ex is 31, result is inf whic is overflow
    assign overflow = (tempEx[5] & (ex < x[14:10])) | (ex == {5{1'b1}});

    assign ex = tempEx[4:0];

endmodule