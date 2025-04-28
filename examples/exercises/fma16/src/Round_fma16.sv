// Luke Summers lsummers@g.hmc.edu 23 Apr 2025

// rounding unit for fma16 module
// inputs:  roundmode - fma control signal
//          sign - sign of result that is being rounded
//          g, r, t - gaurd, round, and sticky bits for result being rounded
//          fracIn - frac for result being rounded
//          exIn - exponent for result being rounded
// outputs: fracOut - rounded frac for result
//          exOut - rounded exponent for result
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
                    // round up if positive and any round bits set
                    exOut = exIn + (((g | r | t) & (!sign)) & (&fracIn));
                    fracOut = fracIn + ((g | r | t) & (!sign));
            end
            // RN
            2'b10: begin
                    // round down if neg and any round bits set
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