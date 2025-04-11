// Luke Summers
// fma16 module to setup the addends for prod + z

module AddendSetup_fma16(
    input  logic zNonZero,
    input  logic [21:0] pIn,
    input  logic [15:0] zIn,
    input  logic [4:0] pEx,
    output logic [68:0] pOut,
    output logic [68:0] zOut

);
    // signs to align normalized inputs for addition
    logic signed [6:0] pExSigned, zExSigned, alignCount;

    // product exponent
    assign pExSigned = {{2{1'b0}}, pEx};

    // if z nonzero, its z's ex if z is zero is prod ex
    assign zExSigned = zNonZero ? {{2{1'b0}}, zIn[14:10]} : {{2{1'b0}}, pEx};

    // difference is how far to shift one
    assign alignCount = pExSigned - zExSigned;

    // command for lint to ignore warning
    /* verilator lint_off WIDTHEXPAND */
    // sets normalized z in the correct alignment in relation to the prod
    // if alignCount[5], then need to manually negate alignCount and switch shift direc
    assign zOut = (alignCount[5]) ? {{29{1'b0}}, zNonZero, zIn[9:0], {29{1'b0}}} << 
                                    (~alignCount + {{4{1'b0}}, {1{1'b1}}}) :
                                    {{29{1'b0}}, zNonZero, zIn[9:0], {29{1'b0}}} >> 
                                    alignCount;
    // command for lint to stop ignoring warning
    /* verilator lint_on WIDTHEXPAND */

    // sets normalized prod in alignment with respect to z in pOut
    // pIn is 2.22, so need to only take pIn[21] if it is set(accounted for in ex)
    assign pOut = pIn[21] ? {{29{1'b0}}, pIn, {18{1'b0}}} : {{29{1'b0}}, pIn[20:0], {19{1'b0}}};

endmodule