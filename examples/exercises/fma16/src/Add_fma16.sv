// Luke Summers
// fma16 module for adding prod + z

module Add_fma16(
    input  logic pSign, zSign,
    input  logic [4:0] pEx,
    input  logic [68:0] p, z,
    output logic sumSign, addOverflow,
    output logic [4:0] sumEx,
    output logic [9:0] sumFrac,
    output logic sumZero
);
    // command for lint to ignore warning
    /* verilator lint_off UNOPTFLAT */
    // intermed signals for exponent calc and decoder output
    logic [6:0] exponentIntermed, offset;
    // command for lint to stop ignoring warning
    /* verilator lint_on UNOPTFLAT */

    // signals for sum and the shifted sum
    logic [68:0] sum, sumShifted;

    // priority decoder, puts the number of the most significant bit with a 1 of sum into offset
    binencoder #(.N(69)) priorityDecoder (.A(sum), .Y(offset));

    always_comb begin

        // if the signs are the same
        if (!(zSign ^ pSign)) begin

            // sign stays the same, magnitude increases
            sumSign = pSign;
            sum = p + z;

        end else if (pSign) begin
            // different signs, prod negative
            if (p > z) begin

                // product negative z positive and product higher magnitude, result will be negative
                sumSign = {1{1'b1}};

                // signs are different, so magnitude lessens
                sum = p - z;

            end else begin

                // product negative z positive and z higher magnitude, result will be positive
                sumSign = {1{1'b0}};

                // signs are different, so magnitude lessens
                sum = z - p;

            end
        end else begin 
            // different signs, z negative
            if (p > z) begin

                // prod positive z negative, prod higher in magnitude so result positive
                sumSign = {1{1'b0}};

                // signs different, so magnitude lessens
                sum = p - z;

            end else begin

                // prod postiive z negative, z higher in magnitude so result negative
                sumSign = {1{1'b1}};

                // signs different, so magnitude lessens
                sum = z - p;

            end

        end

        // sum exponent calculation
        // offset is most significant 1 bit of sum
        // 39 is what offset would be if sum is aligned with the product
        exponentIntermed = offset - 39 + {{2{1'b0}}, pEx};
        sumEx = exponentIntermed[4:0];

        // shifting sum so first 10 fraction bits are in first 10 bits of sum
        sumShifted = sum >> (offset - 10);

        // setting sum fractional bits
        sumFrac = sumShifted[9:0];

        // addition overflows if sum sign is 31
        // addition overfows if the signs are the same and the sum ex is above 31
        // addition overflows if the sum ex is 31
        addOverflow = ((!(pSign ^ zSign)) & (exponentIntermed[5])) | (sumEx == {5{1'b1}});

        // setting the sumZero signal
        // sumZero 1 if the sum is all 0
        // sumZero 0 otherwise
        if (sum == {69{1'b0}}) begin

            sumZero = {1{1'b1}};

        end else begin

            sumZero = {1{1'b0}};

        end

    end

endmodule