// Luke Summers lsummers@g.hmc.edu 23 April 2025

// fma16 module to setup the addend signals
// inputs:  zNonZero - 0 if z zero, 1 otherwise
//          mulUnderflow - 1 if underflow occurred during mul, 0 otherwise
//          mulOverflow - 1 if overflow occurred during mul, 0 otherwise
//          pIn - full 2.22 product from mul
//          zIn - fma input z
//          pEx - exponent of product
// outputs: pOut - aligned and normalized product
//          zOut - aligned and normalized z
module AddendSetup_fma16(
    input  logic zNonZero, mulUnderflow, mulOverflow,
    input  logic [21:0] pIn,
    input  logic [15:0] zIn,
    input  logic [4:0] pEx,
    output logic [70:0] pOut, zOut
);
    // signals to align normalized inputs for addition
    logic signed [6:0] pExSigned, zExSigned, alignCount;

    always_comb begin

        if (mulUnderflow) begin
            // align z as far left as possible
            zOut = {{2{1'b0}}, zNonZero, zIn[9:0], {58{1'b0}}};
            // start product aligned with z
            pOut = pIn[21] ? {{2{1'b0}}, pIn, {47{1'b0}}} : {{2{1'b0}}, pIn[20:0], {48{1'b0}}};
            // shift product over amount of z ex plus amount prod underflowed by
            pOut = pOut >> ({{1{1'b0}}, zIn[14:10]} + {{1{1'b0}}, pEx});
            // temp signs 0
            pExSigned = 7'b0000000;

            zExSigned = 7'b0000000;

            alignCount = 7'b0000000;

        end else if (mulOverflow) begin
            // start p aligned for ex of 30
            pOut = pIn[21] ? {{29{1'b0}}, pIn[21:0], {20{1'b0}}} : {{29{1'b0}}, pIn[20:0], {21{1'b0}}};
            // shift p over for amount it overflowed by
            pOut = pOut << pEx;
            // align z
            zOut = {{30{1'b0}}, zNonZero, zIn[9:0], {30{1'b0}}} >> (30 - zIn[14:10]);
            // temp signs 0
            pExSigned = 7'b0000000;

            zExSigned = 7'b0000000;

            alignCount = 7'b0000000;

        end else begin
             // product exponent
            pExSigned = {{2{1'b0}}, pEx};

            // if z nonzero, its z's ex if z is zero is prod ex
            zExSigned = zNonZero ? {{2{1'b0}}, zIn[14:10]} : {{2{1'b0}}, pEx};

            // difference is how far to shift one
            alignCount = pExSigned - zExSigned;

            // command for lint to ignore warning
            /* verilator lint_off WIDTHEXPAND */
            // sets normalized z in the correct alignment in relation to the prod
            if (alignCount[5]) begin
                // alignCount negative, so need to manually negate alignCount and switch shift direc
                zOut = {{30{1'b0}}, zNonZero, zIn[9:0], {30{1'b0}}} << (~alignCount + {{4{1'b0}}, {1{1'b1}}});

            end else begin
                // alignCount positive, shift to left
                zOut = {{30{1'b0}}, zNonZero, zIn[9:0], {30{1'b0}}} >> alignCount;

            end
            // command for lint to stop ignoring warning
            /* verilator lint_on WIDTHEXPAND */

            // sets normalized prod in alignment with respect to z in pOut
            // pIn is 2.22, so need to only take pIn[21] if it is set(accounted for in ex)
            pOut = pIn[21] ? {{30{1'b0}}, pIn, {19{1'b0}}} : {{30{1'b0}}, pIn[20:0], {20{1'b0}}};

        end

    end

endmodule