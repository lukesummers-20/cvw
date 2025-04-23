// Luke Summers
// fma16 module for selecting what the result is
// selection based on if inputs special cases, or overflow/underflow

module ResultSelector_fma16(
    input  logic xNonZero, yNonZero, zNonZero,
    input  logic xNonInf, yNonInf, zNonInf,
    input  logic noNans, signaling,
    input  logic allNormal,
    input  logic mulOverflow, addOverflow, mulInexact, addInexact, mulUnderflow, sumZero,
    input  logic mul, add, prodSign,
    input  logic [1:0] roundmode,
    input  logic [15:0] x, z, sum,
    output logic [15:0] result,
    output logic [3:0] flags
);
    // overall overflow, inexact signals
    logic overflow, inexact;

    always_comb begin

        // sets overall overflow signal based on operations performed
        if (add) begin
            // add occurred, so add signals
            overflow = addOverflow;
            inexact = addInexact;

        end else begin
            // no add occurred, so mul signals
            overflow = mulOverflow;
            inexact = mulInexact;

        end

        //output logic

        if ((!mul) & (!add)) begin

            // no op so return x
            result = x;
            flags = 4'b0000;
        
        end else if (allNormal) begin 
            // all inputs normal
            if (sumZero) begin
                // sum was 0, so result is 0
                if (roundmode == 2'b11) begin
                    // RP so +0
                    result = {16{1'b0}};
                
                end else if (roundmode == 2'b10) begin
                    // RN so -0
                    result = 16'b1000000000000000;

                end else begin
                    // RNE or RZ so -0 only if both addends neg
                    result = {(prodSign & sum[15]), 15'b000000000000000};

                end 
                // no flags
                flags = 4'b0000;
                
            end else if (overflow) begin

                case(roundmode)
                    // RP
                    2'b11: begin 
                        
                            if (prodSign) begin
                                //-maxnum
                                result = 16'b1111101111111111;

                            end else begin
                                //+inf
                                result = 16'b0111110000000000;

                            end

                        end
                    // RN
                    2'b10: begin 

                            if (prodSign) begin
                                //neg inf
                                result = 16'b1111110000000000;

                            end else begin
                                //+maxnum
                                result = 16'b0111101111111111;

                            end

                        end
                    // RNE
                    2'b01: begin 

                            if (prodSign) begin

                                result = 16'b1111110000000000;

                            end else begin

                                result = 16'b0111110000000000;

                            end

                        end
                    // RZ
                    2'b00: begin 
                            //overflow so round down from inf
                            result = {prodSign, 15'b111101111111111};

                        end

                endcase
                
                flags = 4'b0101;
            
            end else begin
                // no flags, result is the sum
                result = sum;
                flags = {3'b000, inexact};

            end

        end else if (!noNans) begin
            // an operand is nan, so output is nan
            if (signaling) begin 
                // have to set invalid flag
                result = 16'b0111111000000000;//nan
                flags[3] = 1'b1;

            end else if (((!xNonInf) & (!yNonZero)) | ((!xNonZero) & (!yNonInf))) begin
                // have to set invalid flag
                result = 16'b0111111000000000;//nan
                flags[3] = 1'b1;

            end else begin
                // non signaling so invalid not set
                result = 16'b0111111000000000;//nan
                flags[3] = 1'b0;

            end
            // rest of flags not set
            flags[2:0] = 3'b000;

        end else if ((!xNonInf) | (!yNonInf)) begin
            // prod is inf
            if (!zNonInf) begin 

                if (prodSign ^ z[15]) begin
                    // adding opposite signed infities, nan
                    result = 16'b0111111000000000;//nan
                    flags[3] = 1'b1;

                end else begin

                    if ((!xNonZero) | (!yNonZero)) begin

                        result = 16'b0111111000000000;//nan
                        flags[3] = 1'b1;

                    end else begin 
                        // adding same signed infinties, remains same
                        result = z;
                        flags[3] = 1'b0;

                    end

                end

            end else begin

                if ((!xNonZero) | (!yNonZero)) begin 
                    // inf * 0 is nan
                    result = 16'b0111111000000000;//nan
                    flags[3] = 1'b1;

                end else begin 
                    // inf with prod's sign
                    result = {prodSign, 15'b111110000000000};
                    flags[3] = 1'b0;

                end
            end

            flags[2:0] = 3'b000;

        end else if (!zNonInf) begin

            // z is inf, prod is norm/zero
            result = z;
            flags = {4{1'b0}};
        
        end else begin
            // one input is 0
            if (sumZero) begin

                if (zNonZero) begin
                    // prod 0 z normal so z
                    result = z;

                end else begin
                    // sum was 0, so result is 0
                    if (roundmode == 2'b11) begin
                        // RP so only neg 0 if prod and sum neg
                        result = {(sum[15] & prodSign), {15{1'b0}}};
                    
                    end else if (roundmode == 2'b10) begin
                        // RN so neg 0 if prod or sum neg
                        result = {(sum[15] | prodSign), {15{1'b0}}};

                    end else begin 
                        // RNE or RZ, neg 0 only if prod and z neg
                        result = {prodSign & z[15], {15{1'b0}}};

                    end

                end
                // no flags set
                flags = 4'b0000;
            
            end else if ((!xNonZero) | (!yNonZero)) begin 
                // prod 0, so z
                result = z;
                flags = 4'b0000;
                
            end else if (overflow) begin
                
                case(roundmode)
                    // RP
                    2'b11: begin 
                            // -maxnum if neg, inf if pos
                            if (prodSign) begin
                                // -maxnum
                                result = 16'b1111101111111111;

                            end else begin
                                // +inf
                                result = 16'b0111110000000000;

                            end

                        end
                    // RN
                    2'b10: begin 
                            // inf if neg, maxnum if pos
                            if (prodSign) begin
                                // -inf
                                result = 16'b1111110000000000;

                            end else begin
                                // +maxnum
                                result = 16'b0111101111111111;

                            end


                        end
                    // RNE
                    2'b01: begin 
                            // inf signed with prod
                            result = {prodSign, 15'b111110000000000};

                        end
                    // RZ
                    2'b00: begin 
                            //overflow so round down from inf
                            result = {prodSign, 15'b111101111111111};

                        end

                endcase
                // overflow and inexact flag set
                flags = 4'b0101;
            
            end else if (mulUnderflow) begin
                // RP
                if (roundmode == 2'b11) begin
                    // 0 signed with prod
                    result = {prodSign, {15{1'b0}}};
                // RN
                end else if (roundmode == 2'b10) begin
                    // min num if neg, +0 if pos
                    if (prodSign) begin
                        // -min num
                        result = 16'b1000010000000000;

                    end else begin
                        // +0
                        result = {16{1'b0}};

                    end
                // RNE RZ
                end else begin
                    // prod signed zero
                    result = {prodSign, {15{1'b0}}};

                end
                // underflow and inexact flag set
                flags = 4'b0011;

            end else begin
                // no flags other than maybe inexact, result is the sum
                result = sum;
                flags = {3'b000, inexact};

            end

        end

    end

endmodule