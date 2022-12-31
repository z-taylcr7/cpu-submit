
module ALU (
    input clk,input rst,input rdy,
    // input from rs 
    input [`OPENUM_TYPE] in_op, // `NOP to do not calculate
    input [`DATA_TYPE] in_value1,
    input [`DATA_TYPE] in_value2,
    input [`DATA_TYPE] in_imm,
    input [`ADDR_TYPE] in_pc,
    input [`ROB_POS_TYPE] in_rob_tag,
    
    // output to rs/lsb/rob
    output reg [`ROB_POS_TYPE] out_rob_tag, // `ZERO_TAG_ROB means receivers do not treat this data.
    output reg [`DATA_TYPE] out_value,
    output reg [`DATA_TYPE] out_newpc
);





    // Combinatorial logic
    always@(*) begin 
        out_value = `ZERO_WORD;
        out_newpc = `ZERO_ADDR;
        out_rob_tag = `ZERO_ROB;
        if(in_op != `OPENUM_NOP) begin 
            out_rob_tag = in_rob_tag;
            case(in_op)
                `OPENUM_LUI: begin out_value = in_imm; end
                `OPENUM_AUIPC: begin out_value = in_pc + in_imm; end
                `OPENUM_JAL: begin out_value = in_pc + 4;end 
                
                `OPENUM_JALR: begin 
                    out_value = in_pc + 4;
                    out_newpc = in_value1 + in_imm;
                end
                `OPENUM_BEQ:begin 
                    out_value = (in_value1 == in_value2) ? `JUMP_ENABLE : `JUMP_DISABLE;
                    out_newpc = in_pc + in_imm;
                end
                `OPENUM_BNE:begin 
                    out_value = (in_value1 != in_value2) ? `JUMP_ENABLE : `JUMP_DISABLE;
                    out_newpc = in_pc + in_imm;
                end
                `OPENUM_BLT:begin 
                    out_value = ($signed(in_value1) < $signed(in_value2)) ? `JUMP_ENABLE : `JUMP_DISABLE;
                    out_newpc = in_pc + in_imm;
                end
                `OPENUM_BGE: begin 
                    out_value = ($signed(in_value1) >= $signed(in_value2)) ? `JUMP_ENABLE : `JUMP_DISABLE;
                    out_newpc = in_pc + in_imm;
                end
                `OPENUM_BLTU: begin 
                    out_value = (in_value1 < in_value2) ? `JUMP_ENABLE : `JUMP_DISABLE;
                    out_newpc = in_pc + in_imm;
                end
                `OPENUM_BGEU: begin 
                    out_value = (in_value1 >= in_value2) ? `JUMP_ENABLE : `JUMP_DISABLE;
                    out_newpc = in_pc + in_imm;
                end

                `OPENUM_ADDI: begin out_value = in_value1 + in_imm; end
                `OPENUM_SLTI: begin out_value = ($signed(in_value1) < $signed(in_imm)) ? 1 : 0; end
                `OPENUM_SLTIU: begin out_value = (in_value1 < in_imm) ? 1 : 0; end
                `OPENUM_XORI: begin out_value = in_value1 ^ in_imm; end
                `OPENUM_ORI: begin out_value =  in_value1 | in_imm; end   
                `OPENUM_ANDI: begin out_value = in_value1 & in_imm; end  
                `OPENUM_SLLI: begin out_value = in_value1 << in_imm; end
                `OPENUM_SRLI: begin out_value = in_value1 >> in_imm; end
                `OPENUM_SRAI: begin out_value = in_value1 >>> in_imm; end 
                `OPENUM_ADD: begin out_value = in_value1 + in_value2; end 
                `OPENUM_SUB: begin out_value = in_value1 - in_value2; end 
                `OPENUM_SLL: begin out_value = in_value1 << in_value2; end 
                `OPENUM_SLT: begin out_value = ($signed(in_value1) < $signed(in_value2)) ? 1 : 0; end 
                `OPENUM_SLTU: begin out_value = (in_value1 < in_value2) ? 1 : 0; end
                `OPENUM_XOR: begin out_value = in_value1 ^ in_value2; end 
                `OPENUM_SRL: begin out_value = in_value1 >> in_value2; end 
                `OPENUM_SRA: begin out_value = in_value1 >>> in_value2; end 
                `OPENUM_OR: begin out_value = in_value1 | in_value2; end 
                `OPENUM_AND: begin out_value = in_value1 & in_value2; end
            endcase
        end 
    end
endmodule