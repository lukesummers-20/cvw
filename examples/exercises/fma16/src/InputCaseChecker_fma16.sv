// Luke Summers
// fma16 module to check if inputs are normal or a special case

module InputCaseChecker_fma16(
    input  logic [15:0] x, y, z,
    output logic xNonZero, yNonZero, zNonZero,
    output logic xNonInf, yNonInf, zNonInf,
    output logic xNonNan, yNonNan, zNonNan,
    output logic xNormal, yNormal, zNormal
);
    // 1 if input is not equal to 0, 0 if input is 0
    // check lazy bc not required to handle sub norms
    assign xNonZero = (x[14:10] != {5{1'b0}});
    assign yNonZero = (y[14:10] != {5{1'b0}});
    assign zNonZero = (z[14:10] != {5{1'b0}});

    // 1 if input is not inf, 0 if input is inf
    assign xNonInf = (!((x[14:10] == {5{1'b1}}) & (x[9:0] == {10{1'b0}})));
    assign yNonInf = (!((y[14:10] == {5{1'b1}}) & (y[9:0] == {10{1'b0}})));
    assign zNonInf = (!((z[14:10] == {5{1'b1}}) & (z[9:0] == {10{1'b0}})));

    // 1 if input is not nan, 0 if input is nan
    assign xNonNan = (!((x[14:10] == {5{1'b1}}) & (x[9:0] != {10{1'b0}})));
    assign yNonNan = (!((y[14:10] == {5{1'b1}}) & (y[9:0] != {10{1'b0}})));
    assign zNonNan = (!((z[14:10] == {5{1'b1}}) & (z[9:0] != {10{1'b0}})));

    // 1 if input is not any of the special cases, 0 otherwise
    assign xNormal = (xNonZero & xNonInf & xNonNan);
    assign yNormal = (yNonZero & yNonInf & yNonNan);
    assign zNormal = (zNonZero & zNonInf & zNonNan);

endmodule