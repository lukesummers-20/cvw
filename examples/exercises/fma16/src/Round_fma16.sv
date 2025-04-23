// Luke Summers
// rounding unit for fma16 module

module Round_fma16(
    input  logic [1:0] roundmode,
    input  logic sign, g, r, t,
    input  logic [9:0] fracIn,
    input  logic [4:0] exIn,
    output logic [9:0] fracOut,
    output logic [4:0] exOut
);
    always_comb begin

        case(roundmode)
            // RP
            2'b11: begin
                    // round up if positive
                    exOut = exIn + (((g | r | t) & (!sign)) & (&fracIn));

                    fracOut = fracIn + ((g | r | t) & (!sign));

            end
            // RN
            2'b10: begin
                    // round down if neg
                    exOut = exIn + (((g | r | t) & sign) & (&fracIn));

                    fracOut = fracIn + ((g | r | t) & sign);
                    

            end
            // RNE
            2'b01: begin
                    // round if it is to nearest ties even
                    exOut = exIn + (((r | t | fracIn[0]) & g) & (&fracIn));

                    fracOut = fracIn + ((r | t | fracIn[0]) & g);
                    
            end
            // RZ
            2'b00: begin
                    //do nothing, truncate
                    exOut = exIn;
                    fracOut = fracIn;
            end

        endcase

    end

endmodule