// Luke Summers
// fma16 module for selecting what the result is
// selection based on if inputs special cases, or overflow/underflow

module ResultSelector_fma16(
    input  logic xNonZero, yNonZero, zNonZero,
    input  logic xNonInf, yNonInf, zNonInf,
    input  logic xNonNan, yNonNan, zNonNan,
    input  logic xNormal, yNormal, zNormal,
    input  logic mulOverflow, addOverflow, mulUnderflow, sumZero,
    input  logic mul, add,
    input  logic [15:0] x, y, z, prod, sum,
    output logic [15:0] result
);
    // overall overflow signal 
    logic overflow;

    always_comb begin

        // sets overall overflow signal based on operations performed
        case({mul, add})

            // if fma, overflow occurrs if mul and add do, just add does, or mul does with mul underflow
            2'b11: overflow = (mulOverflow & addOverflow) | addOverflow | (mulOverflow & mulUnderflow);

            // if mul onlu, overflow if mul overflow
            2'b10: overflow = mulOverflow;

            // if add only, overflow if add overflow
            2'b01: overflow = addOverflow;

            // if no op dosent matter
            2'b00: overflow = {1{1'b0}};

        endcase

        //output logic

        if ((!mul) & (!add)) begin

            // no op so return x
            result = x;
        
        end else if (xNormal & yNormal & zNormal) begin 
        // all inputs normal
            if (overflow) begin
                //overflow so round down from inf
                result = {prod[15], {4{1'b1}}, {1{1'b0}}, {10{1'b1}}};

            end else if (mulUnderflow) begin 
            // mul underflow
                if (prod[15] ^ z[15]) begin
                // diff sign, so remove smallest amount posibble from z
                    result = {z - {{15{1'b0}}, {1{1'b1}}}};

                end else begin
                // same sign, so z remains same
                    result = z;

                end
            
            end else if (sumZero) begin
            // sum was 0, so result is 0
                result = {16{1'b0}};
            
            end else begin
            // no flags, result is the sum
                result = sum;

            end

        end else if (xNormal & yNormal) begin
        // x and y are normal
            if (!zNonZero) begin
            //z is zero
                if (overflow) begin
                // overflow so round down from inf
                    result = {prod[15], {4{1'b1}}, {1{1'b0}}, {10{1'b1}}};

                end else begin
                // prod normal =result = prod + 0 = prod
                    result = prod;

                end

            end else if (!zNonNan) begin
            //z is nan, so result is nan
                result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

            end else begin 
            //z is inf, so result z
                result = z;

            end 

        end else if (xNormal & zNormal) begin
        // x and z normal
            if (!yNonZero) begin
            // y is zero, so result is 0 + z
                result = z;

            end else if (!yNonNan) begin
            // y is nan, so result is nan
                result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

            end else begin 
            //y is inf so result is prod signed inf
                result = {prod[15], y[14:0]};

            end 

        end else if (yNormal & zNormal) begin
        // y and z normal
            if (!xNonZero) begin
            //x is zero, so result is 0 + z
                result = z;

            end else if (!xNonNan) begin
            //x is nan so result is nan
                result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

            end else begin 
            //x is inf, so result is x
                result = x;

            end 

        end else if (xNormal) begin
        // x normal
            if (!yNonZero) begin
            // y zero
                if (!zNonZero) begin
                // z zero, prod and z zero
                    if (prod[15] ^ z[15]) begin
                    // diff sign so + 0
                        result = {16{1'b0}};

                    end else begin
                    // same sign so prod signed 0
                        result = {prod[15], {15{1'b0}}};

                    end

                end else if (!zNonNan) begin
                // z nan, so result is nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                // z inf so z
                    result = z;

                end 

            end else if (!yNonNan) begin
            // y nana
                if (!zNonZero) begin
                    // z zero, y nan so result nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else if (!zNonNan) begin
                    // z nan, so result nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    // z inf, y nan so result nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end 

            end else begin 
            // y inf
                if (!zNonZero) begin
                    // z zero, y inf so correct signed y
                    result = {prod[15], y[14:0]};

                end else if (!zNonNan) begin
                    // z nan so result nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    // z inf, prod and z inf
                    if (prod[15] ^ z[15]) begin 
                        //diff sign so nan
                        result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                    end else begin
                        //same sign, so same
                        result = z;

                    end

                end 

            end 

        end else if (yNormal) begin
        // y normal
            if (!xNonZero) begin
            // x zero
                if (!zNonZero) begin
                    // z zero
                    if (prod[15] ^ z[15]) begin
                    // dif signs so +0
                        result = {16{1'b0}};

                    end else begin 
                    // same signs so sign same
                        result = {prod[15], {15{1'b0}}};

                    end

                end else if (!zNonNan) begin
                    // z nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    // z inf
                    result = z;

                end 

            end else if (!xNonNan) begin
            // x nan
                if (!zNonZero) begin
                    //x nan z zero
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else if (!zNonNan) begin
                    //x nan z nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    //x nan z inf
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end 

            end else begin 
            // x inf
                if (!zNonZero) begin
                    //x inf z zero
                    result = {prod[15], {5{1'b1}}, {10{1'b0}}};

                end else if (!zNonNan) begin
                    //x inf z nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    //x inf z inf
                    if (prod[15] ^ z[15]) begin 
                        //diff sign so nan
                        result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                    end else begin
                        //same sign, so same
                        result = z;

                    end

                end 

            end 

        end else if (zNormal) begin
        // z normal
            if (!xNonZero) begin
            // x zero
                if (!yNonZero) begin
                    //x zero y zero
                    result = z;

                end else if (!yNonNan) begin
                    //x zero y nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    //x zero y inf
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end 

            end else if (!xNonNan) begin
            // x nan
                if (!yNonZero) begin
                    //x nan y zero
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else if (!yNonNan) begin
                    //x nan y nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    //x nan y inf
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end

            end else begin 
            // x inf
                if (!yNonZero) begin
                    //x inf y zero
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else if (!yNonNan) begin
                    //x inf y nan
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin 
                    //x inf y inf
                    result = {prod[15], {5{1'b1}}, {10{1'b0}}};

                end

            end 
            
        end else begin
            //none are normal
            if ((!xNonNan) | (!yNonNan) | (!zNonNan)) begin
                //x y or z is nan so nan
                result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

            end else if (!zNonInf) begin
            // z inf
                if ((!xNonInf) & (!yNonInf)) begin
                    //prod inf z inf
                    if (prod[15] ^ z[15]) begin
                        //diff sign, so nan
                        result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                    end else begin
                        //same sign, so same
                        result = z;

                    end

                end else if ((!xNonInf) | (!yNonInf)) begin
                    //prod nan z inf
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin
                    //prod 0 z inf
                    result = z;

                end

            end else begin 
            // z zero
                if ((!xNonInf) & (!yNonInf)) begin
                    //prod inf z zero
                    result = {prod[15], {5{1'b1}}, {10{1'b0}}};

                end else if ((!xNonInf) | (!yNonInf)) begin
                    //prod nan z zero
                    result = {{1{1'b0}}, {5{1'b1}}, {1{1'b1}}, {9{1'b0}}};//nan

                end else begin
                    //prod 0 z zero
                    if (prod[15] ^ z[15]) begin
                        // diff sign so + 0
                        result = {16{1'b0}};

                    end else begin
                        // same sign so signed 0
                        result = {prod[15], {15{1'b0}}};

                    end

                end

            end

        end

    end

endmodule