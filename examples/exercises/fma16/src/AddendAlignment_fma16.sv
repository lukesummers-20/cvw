// Luke Summers lsummers@g.hmc.edu 23 April 2025
// fma16 module to setup the addend signals
// inputs:  zNonZero - 0 if z zero, 1 otherwise
//          mulUnderflow - 1 if underflow occurred during mul, 0 otherwise
//          mulOverflow - 1 if overflow occurred during mul, 0 otherwise
//          rAndT - 1 if all bits after gaurd bit in product are 1, 0 otherwise
//          pIn - full 2.22 product from mul
//          zIn - fma input z
//          pEx - exponent of product
// outputs: pOut - aligned and normalized product
//          zOut - aligned and normalized z
//          pAccumulate, zAccumulate - accumulate bits for addends
//          pStickcy - sticky bit for all product bits not in frac, 1 if any are 1, 0 otherwise
module AddendAlignment_fma16(
    input  logic zNonZero, mulUnderflow, mulOverflow, rAndT,
    input  logic [1:0] roundmode,
    input  logic [21:0] pIn,
    input  logic [15:0] zIn,
    input  logic [4:0] pEx,
    input  logic pG, pRT,
    output logic [22:0] pOut, zOut,
    output logic pAccumulate, zAccumulate, pSticky
);
    // signals to align normalized inputs for addition
    logic signed [6:0] pExSigned, zExSigned, alignCount;
    // signals for addends before they get shifted
    logic [22:0] pPreShift, zPreShift;
    always_comb begin
        if (mulUnderflow) begin
            // align z as far left as possible
            zPreShift = {{1{1'b0}}, zNonZero, zIn[9:0], {11{1'b0}}};
            // no shift for z
            zOut = zPreShift;
            // shift p by amount underflowed(pEx) + zEx
            alignCount = ({{1{1'b0}}, zIn[14:10]} + {{1{1'b0}}, pEx});
            // start product aligned with z
            pPreShift = pIn[21] ? {{1{1'b0}}, pIn} : {{1{1'b0}}, pIn[20:0], {1{1'b0}}};
            // shift product over amount of z ex plus amount prod underflowed by
            pOut = pPreShift >> alignCount;
            if (alignCount > 23) begin
                // all of p gets shifted out
                pAccumulate = |(pPreShift);
            end else begin
                // only some of p get shifted out
                pAccumulate = |(pPreShift << (23 - alignCount));
            end
            //no need for these bits
            pSticky = 0;
            zAccumulate = 0;
            pExSigned = 7'b0000000;
            zExSigned = 7'b0000000;
        end else if (mulOverflow) begin
            // start p aligned as left as possible
            pPreShift = pIn[21] ? {{1{1'b0}}, pIn} : {{1{1'b0}}, pIn[20:0], {1{1'b0}}};
            // no need to shift p
            pOut = pPreShift;
            // shifting z by 31 + amount overflowed by(pEx) - zEx
            alignCount = 32 + {{2{1'b0}}, pEx} + ~{{2{1'b0}}, zIn[14:10]};
            // starting z aligned with p
            zPreShift = {{1{1'b0}}, zNonZero, zIn[9:0], {11{1'b0}}};
            // aligning z
            zOut = zPreShift >> alignCount;
            if (alignCount > 23) begin 
                // all of z was shifted out
                zAccumulate = |(zPreShift);
            end else begin
                // some of z was shifted out
                zAccumulate = |(zPreShift << (23 - alignCount));
            end 
            // no need for these bits
            pAccumulate = 0;
            pSticky = 0;
            pExSigned = 7'b0000000;
            zExSigned = 7'b0000000;
        end else begin
             // product exponent
            pExSigned = {{2{1'b0}}, pEx};
            // if z nonzero, its z's ex if z is zero is prod ex
            zExSigned = zNonZero ? {{2{1'b0}}, zIn[14:10]} : {{2{1'b0}}, pEx};
            // difference is how far to shift one
            alignCount = pExSigned - zExSigned;
            // command for lint to ignore warning
            /* verilator lint_off WIDTHEXPAND */
            // align products depending on which greater
            if (alignCount[5]) begin
                // z greater, so align most left and dont shift
                zPreShift = {{1{1'b0}}, zNonZero, zIn[9:0], {11{1'b0}}};
                zOut = zPreShift;
                // start z aligned with z
                pPreShift = pIn[21] ? {{1{1'b0}}, pIn} : {{1{1'b0}}, pIn[20:0], {1{1'b0}}};
                // shift p by how much less its exponent was
                pOut = pPreShift >> (~alignCount + 1);
                // pAccumulate depends on roundmode
                if (roundmode != 2'b01) begin
                    // RN, RP, RZ - normal paccumulate
                    if ((~alignCount + 1) > 23) begin
                        // all of p shifted out
                        pAccumulate = |(pPreShift);
                    end else begin
                        // some of p shifted out
                        pAccumulate = |(pPreShift << (23 - (~alignCount + 1)));
                    end
                    // not used
                    pSticky = 0;
                end else begin
                    // RNE, more complex accumulate to satisfy rounding
                    if ((~alignCount + 1) > 22) begin
                        // all of p shifted out, only need pSticky in this case
                        pAccumulate = 0;
                        pSticky = |(pPreShift);
                    end else if ((~alignCount + 1) > 0) begin 
                        // pAccumulate 1 if g and r | t or all bits after g 1
                        pAccumulate = ((pG & pRT) | rAndT);
                        // sticky is just if there is any bits past products frac
                        pSticky = |(pPreShift << (23 - (~alignCount + 1)));
                    end else begin
                        // p not shifted
                        pAccumulate = 0;
                        pSticky = 0;
                    end
                end
                // not used
                zAccumulate = 0;
            end else begin
                // alignCount positive, p is greater
                // align z all the way to the left
                zPreShift = {{1{1'b0}}, zNonZero, zIn[9:0], {11{1'b0}}};
                // shift over by how much less its exponent was
                zOut = zPreShift >> alignCount;
                // align p all the way to the left
                pPreShift = pIn[21] ? {{1{1'b0}}, pIn} : {{1{1'b0}}, pIn[20:0], {1{1'b0}}};
                // no shift for p
                pOut = pPreShift;
                if (alignCount > 23) begin
                    // all of z shifted out
                    zAccumulate = |(zPreShift);
                end else begin
                    // some of z shifted out
                    zAccumulate = |(zPreShift << (23 - alignCount));
                end
                // not used
                pAccumulate = 0;
                pSticky = 0;
            end
            // command for lint to stop ignoring warning
            /* verilator lint_on WIDTHEXPAND */
        end
    end
endmodule