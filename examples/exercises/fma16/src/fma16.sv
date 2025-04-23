//Luke Summers lsummers@g.hmc.edu
//module for half precision float multiply

module fma16(
    input logic [15:0] x, y, z,
    input logic mul, add, negp, negz,
    input logic [1:0] roundmode,
    output logic [15:0] result,
    output logic [3:0] flags
);
    logic mulSign, fmaSign, mulOverflow, addOverflow, mulUnderflow, mulInexact, addInexact, sumZero;
    logic xNonZero, yNonZero, zNonZero, xNonInf, yNonInf, zNonInf, noNans, signaling, allNormal;
    logic [4:0] roundedMulEx, unroundedMulEx, fmaEx;
    logic [9:0] mulFrac, fmaFrac;
    logic [15:0] correctedX, correctedY, correctedZ;
    logic[21:0] fullMulFrac;
    logic [68:0] alignedZ, expandedProduct;

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
                    .underflow(mulUnderflow), .overflow(mulOverflow), .inexact(mulInexact)
                    );

    // sets up the prod and z to be added
    // puts normalized prod and z into 69 bit signals where their decimal points are aligned
    AddendSetup_fma16 addSetup(
                    .zNonZero(zNonZero), .mulUnderflow(mulUnderflow), .mulOverflow(mulOverflow),
                    .pIn(fullMulFrac), .zIn(correctedZ), .pEx(unroundedMulEx),
                    .pOut(expandedProduct), .zOut(alignedZ)
                    );

    // adds the prod and z
    // overflow signal set to 1 if overflow occurred
    // sumZero signal set to 1 if sum is 0
    Add_fma16 addUnit(
                    .pSign(mulSign), .zSign(correctedZ[15]), .add(add), .mulUnderflow(mulUnderflow), .mulOverflow(mulOverflow),
                    .pEx(unroundedMulEx), .zEx(correctedZ[14:10]),
                    .p(expandedProduct), .z(alignedZ),
                    .roundmode(roundmode),
                    .sign(fmaSign), .ex(fmaEx), .frac(fmaFrac), .overflow(addOverflow), .inexact(addInexact),
                    .zero(sumZero)
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
                                    .mulUnderflow(mulUnderflow), .sumZero(sumZero),
                                    .mul(mul), .add(add), .prodSign(mulSign), .roundmode(roundmode),
                                    .x(correctedX), .z(correctedZ),
                                    .sum({fmaSign, fmaEx, fmaFrac}),
                                    .result(result), .flags(flags)
                                    );

endmodule
