// Luke Summers
// fma16 module to correct inputs for mul, add, negp, negz

module InputCorrecter_fma16 (
    input  logic mul, add, negp, negz,
    input  logic [15:0] x, y, z,
    output logic [15:0] cX, cY, cZ
);
    // if negp is 1, negate x
    assign cX = x ^ (negp << 15);
    // if mul is 1, cY is y if not cY is 1
    assign cY = mul ? y : {{2{1'b0}}, {4{1'b1}}, {10{1'b0}}};
    // if add is 1, cZ is z if not cZ is 0
    // if negz is 1, negate the sign of z
    assign cZ = add ? z ^ (negz << 15) : {16{1'b0}};

endmodule