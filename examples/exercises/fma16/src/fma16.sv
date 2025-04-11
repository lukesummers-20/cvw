//Luke Summers lsummers@g.hmc.edu
//module for half precision float multiply

module fma16(
    input logic [15:0] x, y, z,
    input logic mul, add, negp, negz,
    input logic [1:0] roundmode,
    output logic [15:0] result,
    output logic [3:0] flags
);
    logic mulSign, fmaSign, mulOverflow, addOverflow, mulUnderflow, sumZero;
    logic xNonZero, yNonZero, zNonZero, xNonInf, yNonInf, zNonInf, xNonNan, yNonNan, zNonNan, xNormal, yNormal, zNormal;
    logic [4:0] mulEx, fmaEx;
    logic [9:0] mulFrac, fmaFrac;
    logic [15:0] correctedX, correctedY, correctedZ;
    logic[21:0] tempFrac;
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
                                      .xNonZero(xNonZero), .yNonZero(yNonZero), .zNonZero(zNonZero),
                                      .xNonInf(xNonInf), .yNonInf(yNonInf), .zNonInf(zNonInf),
                                      .xNonNan(xNonNan), .yNonNan(yNonNan), .zNonNan(zNonNan),
                                      .xNormal(xNormal), .yNormal(yNormal), .zNormal(zNormal)
                                      );

    // multiplies x and y, 10 bit frac in mulFrac, full product in tempFrac
    // overflow set to 1 if product overflows
    // underflow set to 1 if product underflows
    Mul_fma16 mulUnit(
                    .xNonZero(xNonZero), .yNonZero(yNonZero),
                    .x(correctedX), .y(correctedY),
                    .sign(mulSign), .ex(mulEx), .frac(mulFrac),
                    .tempFrac(tempFrac), 
                    .underflow(mulUnderflow), .overflow(mulOverflow)
                    );

    // sets up the prod and z to be added
    // puts normalized prod and z into 69 bit signals where their decimal points are aligned
    AddendSetup_fma16 addSetup(
                    .zNonZero(zNonZero), .pIn(tempFrac), .zIn(correctedZ), .pEx(mulEx),
                    .pOut(expandedProduct), .zOut(alignedZ)
                    );

    // adds the prod and z
    // overflow signal set to 1 if overflow occurred
    // sumZero signal set to 1 if sum is 0
    Add_fma16 addUnit(
                    .pSign(mulSign), .zSign(correctedZ[15]), .pEx(mulEx),
                    .p(expandedProduct), .z(alignedZ),
                    .sumSign(fmaSign), .sumEx(fmaEx), .sumFrac(fmaFrac), .addOverflow(addOverflow),
                    .sumZero(sumZero)
                    );

    // selects correct fma result and puts it in result signal
    // accounts for special cases and flows
    ResultSelector_fma16 resultSelect(
                                    .xNonZero(xNonZero), .yNonZero(yNonZero), .zNonZero(zNonZero),
                                    .xNonInf(xNonInf), .yNonInf(yNonInf), .zNonInf(zNonInf),
                                    .xNonNan(xNonNan), .yNonNan(yNonNan), .zNonNan(zNonNan),
                                    .xNormal(xNormal), .yNormal(yNormal), .zNormal(zNormal),
                                    .mulOverflow(mulOverflow), .addOverflow(addOverflow),
                                    .mulUnderflow(mulUnderflow), .sumZero(sumZero),
                                    .mul(mul), .add(add),
                                    .x(correctedX), .y(correctedY), .z(correctedZ),
                                    .prod({mulSign, mulEx, mulFrac}), .sum({fmaSign, fmaEx, fmaFrac}),
                                    .result(result)
                                    );

endmodule
