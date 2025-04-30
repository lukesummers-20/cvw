// Luke Summers lsummers@g.hmc.edu 23 April 2025
// fma16 module for adding prod + z
// inputs:  pSign, zSign - product and z sign
//          add - fma control signal
//          mulUnderflow - 1 if mul op underflowed, 0 otherwise
//          mulOverflow - 1 if mul op overflowed, 0 otherwise
//          pEx, zEx - product and z exponent
//          p, z - aligned and normalized product and z
//          roundmode - fma control signal
// outputs: overflow - 1 if overflow occurred, 0 otherwise
//          inexact - 1 if result inexact, 0 otherwise
//          sign - result sign
//          ex - result exponent
//          frac - result fraction
//          zero - 1 if result 0, 0 otherwise
//          subnorm - 1 if result subnorm, 0 otherwise
module Add_fma16(
    input  logic pSign, zSign, mul, add, mulUnderflow, mulOverflow, pAccumulate, zAccumulate, pSticky,
    input  logic [4:0] pEx, zEx,
    input  logic [22:0] p, z,
    input  logic [1:0] roundmode,
    output logic sign, overflow, inexact,
    output logic [4:0] ex,
    output logic [9:0] frac,
    output logic zero, subnorm
);
    // command for lint to ignore warning
    /* verilator lint_off UNOPTFLAT */
    // intermed signals for exponent calc and decoder output
    logic [5:0] exponentIntermed;
    logic [4:0] offset;
    // command for lint to stop ignoring warning
    /* verilator lint_on UNOPTFLAT */
    // signals for sum and the shifted sum
    logic [22:0] sum, sumShifted, gMask, rMask, tMask;
    // rounding signals
    logic g, r, t;
    // pre round frac
    logic [9:0] unroundedFrac;
    // pre round ex
    logic[4:0] unroundedEx;
    // priority decoder, puts the number of the most significant bit with a 1 of sum into offset
    binencoder #(.N(23)) priorityDecoder (.A(sum), .Y(offset));
    // rounding handler
    Round_fma16 addRounder(.roundmode(roundmode), .sign(sign), .g(g), .r(r), .t(t),
                            .fracIn(unroundedFrac), .exIn(unroundedEx), .fracOut(frac), .exOut(ex));
    always_comb begin
        // finding sum and sign
        if (zSign ^ pSign) begin   
            // different signs
            if (p > z) begin
                if (roundmode == 2'b11) begin
                    // RP
                    if (pSign) begin
                        sum = p - z - {{22{1'b0}}, zAccumulate};
                    end else begin
                        sum = p - z;
                    end
                end else if (roundmode == 2'b10) begin
                    // RN
                    if (pSign) begin
                        sum = p - z;
                    end else begin
                        sum = p - z - {{22{1'b0}}, zAccumulate};
                    end
                end else if (roundmode == 2'b01) begin
                    sum = p - z - {{22{1'b0}}, zAccumulate};
                end else begin
                    sum = p - z - {{22{1'b0}}, zAccumulate};
                end
                // product higher magnitude, sum has sign of prod
                sign = pSign;
            end else begin
                if (roundmode == 2'b11) begin
                    // RP
                    if (pSign) begin
                        sum = z - p;
                    end else begin
                        sum = z - p - {{22{1'b0}}, pAccumulate};
                    end
                end else if (roundmode == 2'b10) begin
                    // RN
                    if (pSign) begin
                        sum = z - p - {{22{1'b0}}, pAccumulate};
                    end else begin
                        sum = z - p;
                    end
                end else if (roundmode == 2'b01) begin
                    if(mul) begin
                        sum = z - p - {{22{1'b0}}, pAccumulate};
                    end else begin
                        sum = z - p;
                    end
                end else begin
                    sum = z - p - {{22{1'b0}}, pAccumulate};
                end
                // z higher maginitude, sum has sign of z
                sign = zSign;
            end
                
        end else begin 
            // same signs, sign stays the same, magnitude increases
            if (roundmode == 2'b11) begin
                // RP
                if (pSign) begin
                    sum = p + z;
                end else begin
                    sum = p + z + {{22{1'b0}}, pAccumulate} + {{22{1'b0}}, zAccumulate};
                end
            end else if (roundmode == 2'b10) begin
                // RN
                if (pSign) begin
                    sum = p + z + {{22{1'b0}}, pAccumulate} + {{22{1'b0}}, zAccumulate};
                end else begin
                    sum = p + z;
                end
            end else if (roundmode == 2'b01) begin
                sum = p + z;
            end else begin
                sum = p + z;
            end
            sign = pSign;
        end
        // sum exponent calculation
        // offset is most significant 1 bit of sum
        // 39 is what offset would be if sum is aligned with the product
        if (mulUnderflow) begin
            // addends start aligned to bit 69 with z's ex
            exponentIntermed = {{1{1'b0}}, offset} - 21 + {{1{1'b0}}, zEx};
        end else if (mulOverflow) begin
            // addends start aligned to bit 40 with ex of 30
            exponentIntermed = {{1{1'b0}}, offset} + 10 + {{1{1'b0}}, pEx};
        end else begin
            // addends start aligned to bit 40  with ex of prod
            if ({{1{1'b0}}, offset} + {{1{1'b0}}, pEx} < 21) begin
                exponentIntermed = {{1{1'b0}}, zEx} + {{1{1'b0}}, offset} - 21;
            end else begin 
                if (p > z) begin
                    exponentIntermed = {{1{1'b0}}, offset} - 21 + {{1{1'b0}}, pEx};
                end else begin
                    exponentIntermed = {{1{1'b0}}, offset} - 21 + {{1{1'b0}}, zEx};
                end
            end
        end
        // setting sum ex
        unroundedEx = exponentIntermed[4:0];
        // shifting sum so first 10 fraction bits are in first 10 bits of sum
        if (offset < 10) begin
            sumShifted = sum << (10 - offset);
        end else begin
            sumShifted = sum >> (offset - 10);
        end
        // setting sum fractional bits
        unroundedFrac = sumShifted[9:0];
        // setting rounding bit masks
        if (offset > 12) begin 
            // sum large enough for all bits
            gMask = {{22{1'b0}}, {1{1'b1}}} << (offset - 11);
            rMask = {{22{1'b0}}, {1{1'b1}}} << (offset - 12);
            tMask = {23{1'b1}} >> (35 - offset);
        end else if (offset == 12) begin 
            // sum large enough for g and r
            gMask = {{22{1'b0}}, {1{1'b1}}} << (offset - 11);
            rMask = {{22{1'b0}}, {1{1'b1}}} << (offset - 12);
            tMask = {23{1'b0}};
        end else if (offset == 11) begin 
            // sum large enough for g 
            gMask = {{22{1'b0}}, {1{1'b1}}} << (offset - 11);
            rMask = {23{1'b0}};
            tMask = {23{1'b0}};
        end else begin 
            // no rounding bits
            gMask = {23{1'b0}};
            rMask = {23{1'b0}};
            tMask = {23{1'b0}};
        end
        // setting rounding bits
        g = |(gMask & sum);
        r = |(rMask & sum);
        t = |(tMask & sum);
        // setting overflow for addition
        overflow = (((!mulUnderflow) & (exponentIntermed > 30)) | (ex == 5'b11111));
        // setting the sumZero signal
        // 1 if sum is 0, 0 otherwise
        zero = !(|sum);
        // setting sumSubnorm signal
        // 1 if sum is subnormal, 0 otherwise
        subnorm = ((exponentIntermed == 6'b000000) & (ex == 5'b00000) & (!zero));
        // setting inexact signal
        inexact = g | r | t | overflow | pSticky | pAccumulate | zAccumulate;
    end
endmodule