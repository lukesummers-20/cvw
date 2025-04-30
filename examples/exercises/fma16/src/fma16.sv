//Luke Summers lsummers@g.hmc.edu 23 Apr 2025

// module for half precision float multiply
// inputs:  x, y, z - values for x * y + z, in half precision float {sign[15], ex[14:10], frac[9:0]}
//          mul - control signal to enable mul operation, if 0 y forced to 1
//          add - control signal to enable add operation, if 0 z forced to 0
//          negp - control signal to negate sign of product, if 1 product's sign flipped
//          negz - control signal to negate sign of z, if 1 z's sign flipped
//          roundmode - control signal for adhering to different rounding modes
//                      {RZ : 00, RNE : 01, RM(Round Negative):10, RP: 11}
// outputs: result - value of x * y + z in half precision float {sign[15], ex[14:10], frac[9:0]}
//          flags - fma operation output flags{invalid, overflow, underflow, inexact}
module fma16(
    input logic [15:0] x, y, z,
    input logic mul, add, negp, negz,
    input logic [1:0] roundmode,
    output logic [15:0] result,
    output logic [3:0] flags
);
    logic mulSign, fmaSign, mulOverflow, addOverflow, mulUnderflow, mulInexact, addInexact, sumZero, sumSubnorm, pAccumulate, zAccumulate, rAndT, pSticky, pG, pRT;
    logic xNonZero, yNonZero, zNonZero, xNonInf, yNonInf, zNonInf, noNans, signaling, allNormal;
    /* verilator lint_off UNOPTFLAT */
    logic [4:0] roundedMulEx, unroundedMulEx, fmaEx;
    /* verilator lint_on UNOPTFLAT */
    logic [9:0] mulFrac, fmaFrac;
    logic [15:0] correctedX, correctedY, correctedZ;
    logic[21:0] fullMulFrac;
    logic [22:0] alignedZ, expandedProduct;
    // get correct input signals for x, y, and z based on the control signals
    // negp : negates x * y
    // negz : negates z
    // mul  : if 1 product is x * y if 0 product is x * 1
    // add  : if 1 sum is product + z if 0 sum is product + 0
    InputCorrecter_fma16 inputCorrection (.mul(mul), .add(add), .negp(negp), .negz(negz), 
                                          .x(x), .y(y), .z(z), 
                                          .cX(correctedX), .cY(correctedY), .cZ(correctedZ)
                                          );
    // check if any inputs are a special case(zero, infinity, nan)
    InputCaseChecker_fma16 inputCases (
                                      .x(correctedX), .y(correctedY), .z(correctedZ),
                                      .mul(mul), .add(add),
                                      .xNonZero(xNonZero), .yNonZero(yNonZero), .zNonZero(zNonZero),
                                      .xNonInf(xNonInf), .yNonInf(yNonInf), .zNonInf(zNonInf),
                                      .noNans(noNans), .signaling(signaling),
                                      .allNormal(allNormal)
                                      );
    // multiplies x and y, 10 bit frac in mulFrac, full product in tempFrac
    // overflow set to 1 if product overflows
    // underflow set to 1 if product underflows
    Mul_fma16 mulUnit(
                    .xNonZero(xNonZero), .yNonZero(yNonZero), .xNonInf(xNonInf), .yNonInf(yNonInf), .add(add),
                    .roundmode(roundmode),
                    .x(correctedX), .y(correctedY),
                    .sign(mulSign), .roundedEx(roundedMulEx), .unroundedEx(unroundedMulEx), .frac(mulFrac),
                    .fullFrac(fullMulFrac), 
                    .underflow(mulUnderflow), .overflow(mulOverflow), .inexact(mulInexact), .rAndT(rAndT), .g(pG), .rt(pRT)
                    );
    // sets up the prod and z to be added
    // puts normalized prod and z into 69 bit signals where their decimal points are aligned
    AddendAlignment_fma16 addSetup(
                    .zNonZero(zNonZero), .mulUnderflow(mulUnderflow), .mulOverflow(mulOverflow), .rAndT(rAndT), .roundmode(roundmode),
                    .pIn(fullMulFrac), .zIn(correctedZ), .pEx(unroundedMulEx), .pG(pG), .pRT(pRT),
                    .pOut(expandedProduct), .zOut(alignedZ), .pAccumulate(pAccumulate), .zAccumulate(zAccumulate), .pSticky(pSticky)
                    );
    // adds the prod and z
    // overflow signal set to 1 if overflow occurred
    // sumZero signal set to 1 if sum is 0
    Add_fma16 addUnit(
                    .pSign(mulSign), .zSign(correctedZ[15]), .mul(mul), .add(add), .mulUnderflow(mulUnderflow), .mulOverflow(mulOverflow),
                    .pAccumulate(pAccumulate), .zAccumulate(zAccumulate), .pSticky(pSticky),
                    .pEx(unroundedMulEx), .zEx(correctedZ[14:10]),
                    .p(expandedProduct), .z(alignedZ),
                    .roundmode(roundmode),
                    .sign(fmaSign), .ex(fmaEx), .frac(fmaFrac), .overflow(addOverflow), .inexact(addInexact),
                    .zero(sumZero), .subnorm(sumSubnorm)
                    );
    // selects correct fma result and puts it in result signal
    // accounts for special cases and flows
    ResultSelector_fma16 resultSelect(
                                    .xNonZero(xNonZero), .yNonZero(yNonZero), .zNonZero(zNonZero),
                                    .xNonInf(xNonInf), .yNonInf(yNonInf), .zNonInf(zNonInf),
                                    .noNans(noNans), .signaling(signaling),
                                    .allNormal(allNormal),
                                    .mulOverflow(mulOverflow), .addOverflow(addOverflow),
                                    .mulInexact(mulInexact), .addInexact(addInexact),
                                    .mulUnderflow(mulUnderflow), .sumZero(sumZero), .sumSubnorm(sumSubnorm),
                                    .mul(mul), .add(add), .prodSign(mulSign), .roundmode(roundmode),
                                    .x(correctedX), .z(correctedZ),
                                    .sum({fmaSign, fmaEx, fmaFrac}),
                                    .result(result), .flags(flags)
                                    );

endmodule
