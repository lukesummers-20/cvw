// Luke Summers lsummers@g.hmc.edu 23 April 2025

// fma16 module to correct inputs for mul, add, negp, negz
// inputs:  mul - fma mul control signal
//          add - fma add control signal
//          negp - fma product negation signal
//          negz - fma z negation signal
//          x, y, z - fma inputs
// outputs: cX, cY, cZ - corrected fma inputs
module InputCorrecter_fma16 (
    input  logic mul, add, negp, negz,
    input  logic [15:0] x, y, z,
    output logic [15:0] cX, cY, cZ
);
    // if negp is 1, negate x
    assign cX = x ^ {negp, 15'b000000000000000};
    // if mul is 1, cY is y if not cY is 1
    assign cY = mul ? y : 16'b0011110000000000;
    // if add is 1, cZ is z if not cZ is 0
    // if negz is 1, negate the sign of z
    assign cZ = add ? z ^ {negz, 15'b000000000000000} : {16{1'b0}};

endmodule