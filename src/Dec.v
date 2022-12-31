

module decoder (
    input clk,input rst,input rdy,

    // From Fetcher
    input [`DATA_TYPE] in_fetcher_instr,
    input [`DATA_TYPE] in_fetcher_pc,
    input in_fetcher_jump_flag,

    // ask register for source operand status
    output [`REG_POS_TYPE] out_reg_tag1,
    input [`DATA_TYPE] in_reg_value1,
    input [`ROB_POS_TYPE] in_reg_robtag1,
    input in_reg_busy1,

    output [`REG_POS_TYPE] out_reg_tag2,
    input [`DATA_TYPE] in_reg_value2,
    input [`ROB_POS_TYPE] in_reg_robtag2,
    input in_reg_busy2,

    // ask registers to update value type
    output reg [`REG_POS_TYPE] out_reg_dest,  //use this == zero to check whether it is send to register
    output [`ROB_POS_TYPE] out_reg_rob_tag,

    // Get free rob entry tag
    input [`ROB_POS_TYPE] in_rob_freetag,

    // ask rob for source operand value
    output [`ROB_POS_TYPE] out_rob_fetch_tag1,
    input [`DATA_TYPE] in_rob_fetch_value1,
    input in_rob_fetch_ready1,
    output [`ROB_POS_TYPE] out_rob_fetch_tag2,
    input [`DATA_TYPE] in_rob_fetch_value2,
    input in_rob_fetch_ready2,

    // ask rob to store entry
    output reg [`DATA_TYPE] out_rob_dest, // need to distinguish register name from memory address
    output reg [`OPENUM_TYPE] out_rob_op,
    output out_rob_jump_flag,

    // ask rs to store entry
    output reg [`ROB_POS_TYPE] out_rs_rob_tag, //use this == zero to check whether it is send to rs
    output reg [`OPENUM_TYPE] out_rs_op,
    output reg [`DATA_TYPE] out_rs_value1,
    output reg [`DATA_TYPE] out_rs_value2,
    output reg [`ROB_POS_TYPE] out_rs_tag1,
    output reg [`ROB_POS_TYPE] out_rs_tag2,
    output reg [`DATA_TYPE] out_rs_imm,
    // for rs and rob
    output [`DATA_TYPE] out_pc,

    // ask lsb to store entry
    output reg [`ROB_POS_TYPE] out_lsb_rob_tag, //use this == lsb to check whether it is send to lsb
    output reg [`OPENUM_TYPE] out_lsb_op,
    output reg [`DATA_TYPE] out_lsb_value1,
    output reg [`DATA_TYPE] out_lsb_value2,
    output reg [`ROB_POS_TYPE] out_lsb_tag1,
    output reg [`ROB_POS_TYPE] out_lsb_tag2,
    output reg [`DATA_TYPE] out_lsb_imm

);
    
    wire [6:0] opcode;
    wire [4:0]  rd;
    wire [2:0] funct3; 
    wire [6:0] funct7;
    parameter LUI = 7'b0110111,AUIPC = 7'b0010111,JAL = 7'b1101111,JALR = 7'b1100111,
    B_TYPE = 7'b1100011,LI_TYPE = 7'b0000011,S_TYPE = 7'b0100011,AI_TYPE = 7'b0010011,R_TYPE = 7'b0110011;
    
    assign opcode = in_fetcher_instr[`OPCODE_RANGE];
    assign funct3 = in_fetcher_instr[14:12];
    assign funct7 = in_fetcher_instr[31:25];
    assign rd = in_fetcher_instr[11:7];

    assign out_reg_tag1 = in_fetcher_instr[19:15];
    assign out_reg_tag2 = in_fetcher_instr[24:20];
    assign out_rob_fetch_tag1 = in_reg_robtag1;
    assign out_rob_fetch_tag2 = in_reg_robtag2;
    assign out_reg_rob_tag = in_rob_freetag;
    assign out_pc = in_fetcher_pc;
    assign out_rob_jump_flag = in_fetcher_jump_flag;

    wire [`DATA_TYPE] value1; wire [`DATA_TYPE] value2; wire[`ROB_POS_TYPE] tag1;wire [`ROB_POS_TYPE] tag2;
    assign value1 = (in_reg_busy1 == `FALSE) ? in_reg_value1 : (in_rob_fetch_ready1 == `TRUE) ? in_rob_fetch_value1 : `ZERO_WORD;
    assign tag1 = (in_reg_busy1 == `FALSE) ? `ZERO_ROB : (in_rob_fetch_ready1 == `TRUE) ? `ZERO_ROB : in_reg_robtag1;
    assign value2 = (in_reg_busy2 == `FALSE) ? in_reg_value2 : (in_rob_fetch_ready2 == `TRUE) ? in_rob_fetch_value2 : `ZERO_WORD;
    assign tag2 = (in_reg_busy2 == `FALSE) ? `ZERO_ROB : (in_rob_fetch_ready2 == `TRUE) ? `ZERO_ROB : in_reg_robtag2;

    always @(*) begin
        out_rob_dest = `ZERO_REG;
        out_rob_op = `OPENUM_NOP;
        out_rs_rob_tag = `ZERO_ROB;
        out_rs_op = `OPENUM_NOP;
        out_rs_imm = `ZERO_WORD;
        out_lsb_op = `OPENUM_NOP;
        out_lsb_imm = `ZERO_WORD;
        out_lsb_rob_tag = `ZERO_ROB;
        out_reg_dest = `ZERO_REG;
        out_rs_value1 = `ZERO_WORD;
        out_rs_tag1 = `ZERO_ROB;
        out_rs_value2 = `ZERO_WORD;
        out_rs_tag2 = `ZERO_ROB;
        out_lsb_value1 = `ZERO_WORD;
        out_lsb_tag1 = `ZERO_ROB;
        out_lsb_value2 = `ZERO_WORD;
        out_lsb_tag2 = `ZERO_ROB;

        if(rst == `FALSE && rdy == `TRUE) begin 
            case (opcode)
                LUI:begin
                  out_rob_op = `OPENUM_LUI;
                  out_rob_dest = {27'b0,rd[4:0]};
                  out_rs_rob_tag = in_rob_freetag;
                  out_rs_op = `OPENUM_LUI;
                  out_rs_imm = {in_fetcher_instr[31:12],12'b0};
                  out_reg_dest = rd;
                end
                AUIPC:begin
                  out_rob_op = `OPENUM_AUIPC;
                  out_rob_dest = {27'b0,rd[4:0]};
                  out_rs_rob_tag = in_rob_freetag;
                  out_rs_op = `OPENUM_AUIPC;
                  out_rs_imm = {in_fetcher_instr[31:12],12'b0};
                  out_reg_dest = rd;
                end
                JAL:begin 
                    out_rob_op = `OPENUM_JAL;
                    out_rob_dest = {27'b0,rd[4:0]};
                    out_rs_rob_tag = in_rob_freetag;
                    out_rs_op = `OPENUM_JAL;
                    out_reg_dest = rd;
                end
                JALR:begin 
                    out_rob_op = `OPENUM_JALR;
                    out_rob_dest = {27'b0,rd[4:0]};
                    out_rs_rob_tag = in_rob_freetag;
                    out_rs_op = `OPENUM_JALR;
                    out_rs_value1 = value1;
                    out_rs_tag1 = tag1;
                    out_rs_imm = {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:20]};
                    out_reg_dest = rd;
                end
                B_TYPE:begin 
                    out_rs_rob_tag = in_rob_freetag;
                    out_rs_value1 = value1;
                    out_rs_tag1 = tag1;
                    out_rs_value2 = value2;
                    out_rs_tag2 = tag2;
                    out_rs_imm = {{20{in_fetcher_instr[31]}},in_fetcher_instr[7],in_fetcher_instr[30:25],in_fetcher_instr[11:8], 1'b0};
                    case(funct3) 
                        3'b000:begin    out_rs_op = `OPENUM_BEQ;     out_rob_op = `OPENUM_BEQ; end
                        3'b001:begin    out_rs_op = `OPENUM_BNE;     out_rob_op = `OPENUM_BNE; end
                        3'b100:begin    out_rs_op = `OPENUM_BLT;     out_rob_op = `OPENUM_BLT; end
                        3'b101:begin    out_rs_op = `OPENUM_BGE;     out_rob_op = `OPENUM_BGE; end
                        3'b110:begin    out_rs_op = `OPENUM_BLTU;    out_rob_op = `OPENUM_BLTU; end
                        3'b111:begin    out_rs_op = `OPENUM_BGEU;    out_rob_op = `OPENUM_BGEU; end
                    endcase
                end
                LI_TYPE:begin 
                    out_rob_dest = {27'b0,rd[4:0]};
                    out_lsb_rob_tag = in_rob_freetag;
                    out_lsb_value1 = value1;
                    out_lsb_tag1 = tag1;
                    out_lsb_imm = {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:20]};
                    out_reg_dest = rd;
                    case(funct3) 
                        3'b000:begin    out_lsb_op = `OPENUM_LB;     out_rob_op = `OPENUM_LB; end
                        3'b001:begin    out_lsb_op = `OPENUM_LH;     out_rob_op = `OPENUM_LH; end
                        3'b010:begin    out_lsb_op = `OPENUM_LW;     out_rob_op = `OPENUM_LW; end
                        3'b100:begin    out_lsb_op = `OPENUM_LBU;    out_rob_op = `OPENUM_LBU; end
                        3'b101:begin    out_lsb_op = `OPENUM_LHU;    out_rob_op = `OPENUM_LHU; end
                    endcase
                end
                S_TYPE:begin
                    out_lsb_rob_tag = in_rob_freetag;
                    out_lsb_value1 = value1;
                    out_lsb_tag1 = tag1;
                    out_lsb_value2 = value2;
                    out_lsb_tag2 = tag2;
                    out_lsb_imm = {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:25],in_fetcher_instr[11:7]};
                    case(funct3) 
                        3'b000:begin    out_lsb_op = `OPENUM_SB;    out_rob_op = `OPENUM_SB; end
                        3'b001:begin    out_lsb_op = `OPENUM_SH;    out_rob_op = `OPENUM_SH; end
                        3'b010:begin    out_lsb_op = `OPENUM_SW;    out_rob_op = `OPENUM_SW; end
                    endcase
                end
                AI_TYPE:begin 
                    out_rob_dest = {27'b0,rd[4:0]};
                    out_rs_rob_tag = in_rob_freetag;
                    out_rs_value1 = value1;
                    out_rs_tag1 = tag1;
                    out_rs_imm = {{21{in_fetcher_instr[31]}},in_fetcher_instr[30:20]};
                    out_reg_dest = rd;
                    case(funct3) 
                        3'b000:begin    out_rs_op = `OPENUM_ADDI;    out_rob_op = `OPENUM_ADDI; end
                        3'b010:begin    out_rs_op = `OPENUM_SLTI;    out_rob_op = `OPENUM_SLTI; end
                        3'b011:begin    out_rs_op = `OPENUM_SLTIU;   out_rob_op = `OPENUM_SLTIU; end
                        3'b100:begin    out_rs_op = `OPENUM_XORI;    out_rob_op = `OPENUM_XORI; end
                        3'b110:begin    out_rs_op = `OPENUM_ORI;     out_rob_op = `OPENUM_ORI; end
                        3'b111:begin    out_rs_op = `OPENUM_ANDI;    out_rob_op = `OPENUM_ANDI; end
                        3'b001:begin 
                            out_rs_op = `OPENUM_SLLI;
                            out_rob_op = `OPENUM_SLLI;
                            out_rs_imm = {26'b0,in_fetcher_instr[25:20]};
                        end
                        3'b101:begin 
                            out_rs_imm = {26'b0,in_fetcher_instr[25:20]};
                            case(funct7)
                                7'b0000000:begin out_rs_op = `OPENUM_SRLI; out_rob_op = `OPENUM_SRLI; end
                                7'b0100000:begin out_rs_op = `OPENUM_SRAI; out_rob_op = `OPENUM_SRAI; end
                            endcase
                        end
                    endcase
                end
                R_TYPE:begin 
                    out_rs_value1 = value1;
                    out_rs_tag1 = tag1;
                    out_rs_value2 = value2;
                    out_rs_tag2 = tag2;
                    out_rob_dest = {27'b0,rd[4:0]};
                    out_rs_rob_tag = in_rob_freetag;
                    out_reg_dest = rd;
                    case(funct3)
                        3'b000:begin 
                            case(funct7)
                                7'b0000000:begin out_rs_op = `OPENUM_ADD; out_rob_op = `OPENUM_ADD; end
                                7'b0100000:begin out_rs_op = `OPENUM_SUB; out_rob_op = `OPENUM_SUB; end
                            endcase
                        end
                        3'b001:begin out_rs_op = `OPENUM_SLL; out_rob_op = `OPENUM_SLL; end
                        3'b010:begin out_rs_op = `OPENUM_SLT; out_rob_op = `OPENUM_SLT; end
                        3'b011:begin out_rs_op = `OPENUM_SLTU; out_rob_op = `OPENUM_SLTU; end
                        3'b100:begin out_rs_op = `OPENUM_XOR; out_rob_op = `OPENUM_XOR; end
                        3'b101:begin 
                            case(funct7)
                                7'b0000000:begin out_rs_op = `OPENUM_SRL; out_rob_op = `OPENUM_SRL; end
                                7'b0100000:begin out_rs_op = `OPENUM_SRA; out_rob_op = `OPENUM_SRA; end
                            endcase
                        end
                        3'b110:begin out_rs_op = `OPENUM_OR; out_rob_op = `OPENUM_OR; end
                        3'b111:begin out_rs_op = `OPENUM_AND; out_rob_op = `OPENUM_AND; end
                    endcase
                end
            endcase
        end
    end
    endmodule