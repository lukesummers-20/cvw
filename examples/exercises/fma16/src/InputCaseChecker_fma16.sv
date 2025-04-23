// Luke Summers lsummers@g.hmc.edu 23 April 2025

// fma16 module to check if inputs are normal or a special case
// inputs:  x, y, z - fma inputs {sign([15]), ex([14:10]), frac([9:0])}
//          mul, add - fma control signals to multiply and/or add
// outputs: xNonZero, yNonZero, zNonZero - 0 if input is 0, 1 otherwise
//          xNonInf, yNonInf, zNonInf - 0 if input is infinity, 1 otherwise
//          noNans - 0 if any input is nan, 1 otherwise
//          signlaing - 1 if any input is signaling nan, 0 otherwise
//          allNormal - 1 if all inputs normal, 0 otherwise
module InputCaseChecker_fma16(
    input  logic [15:0] x, y, z,
    input  logic mul, add,
    output logic xNonZero, yNonZero, zNonZero,
    output logic xNonInf, yNonInf, zNonInf,
    output logic noNans, signaling,
    output logic allNormal
);
    // temp signals
    logic xNonNan, yNonNan, zNonNan; 
    logic xNormal, yNormal, zNormal; 
    logic xSignaling, ySignaling, zSignaling;

    // 0 if input is 0, 1 otherwise
    // check lazy bc not required to handle sub norms
    assign xNonZero = (x[14:10] != {5{1'b0}});
    assign yNonZero = (y[14:10] != {5{1'b0}});
    assign zNonZero = (z[14:10] != {5{1'b0}});

    // 0 if input is inf, 1 otherwise
    assign xNonInf = (!((x[14:10] == {5{1'b1}}) & (x[9:0] == {10{1'b0}})));
    assign yNonInf = (!((y[14:10] == {5{1'b1}}) & (y[9:0] == {10{1'b0}})));
    assign zNonInf = (!((z[14:10] == {5{1'b1}}) & (z[9:0] == {10{1'b0}})));

    // 0 if input is nan, 1 otherwise
    assign xNonNan = (!((x[14:10] == {5{1'b1}}) & (x[9:0] != {10{1'b0}})));
    // 1 if input signaling nan, 0 otherwise
    assign xSignaling = ((!xNonNan) & (!x[9]));
    assign yNonNan = (!((y[14:10] == {5{1'b1}}) & (y[9:0] != {10{1'b0}})));
    assign ySignaling = ((!yNonNan) & (!y[9]));
    assign zNonNan = (!((z[14:10] == {5{1'b1}}) & (z[9:0] != {10{1'b0}})));
    assign zSignaling = ((!zNonNan) & (!z[9]));

    // 0 if any input is nan, 1 otherwise
    assign noNans = xNonNan & yNonNan & zNonNan;
    // 1 if any input is signaling nan, 0 otherwise
    assign signaling = xSignaling | ySignaling | zSignaling;
    
    // 1 if input is normal, 0 otherwise
    assign xNormal = (xNonZero & xNonInf & xNonNan);
    assign yNormal = (yNonZero & yNonInf & yNonNan);
    assign zNormal = (zNonZero & zNonInf & zNonNan);

    // 1 if all inputs normal, 0 otherwise
    assign allNormal = xNormal & yNormal & zNormal;

endmodule