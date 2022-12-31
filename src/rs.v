
module RS (
    input clk,input rst,input rdy,
    // from fetcher to decide whether to store the input
    input in_fetcher_flag,

    // for fetcher to decide whether to fetch new instruction
    output out_fetcher_idle,

    // from decode to store entry, use rob_tag == `ZERO_ROB to decide whether to store
    input [`ROB_POS_TYPE] in_decoder_rob,
    input [`OPENUM_TYPE] in_decoder_op,
    input [`DATA_TYPE] in_decoder_value1,
    input [`DATA_TYPE] in_decoder_value2,
    input [`DATA_TYPE] in_decoder_imm,
    input [`ROB_POS_TYPE] in_decoder_tag1, 
    input [`ROB_POS_TYPE] in_decoder_tag2,
    input [`DATA_TYPE] in_decoder_pc,

    // from alu_cdb to update source value
    input [`DATA_TYPE] in_alu_cdb_value,
    input [`ROB_POS_TYPE] in_alu_cdb_pos, // use this == `ZERO_ROB to check legality
    // from rob_cdb to update source value 
    input [`ROB_POS_TYPE] in_rob_cdb_pos,
    input [`DATA_TYPE] in_rob_cdb_value,
    // from lsb_cdb to update source value 
    input [`ROB_POS_TYPE] in_lsb_cdb_pos, // use this == `ZERO_ROB to check legality
    input [`DATA_TYPE] in_lsb_cdb_value,
    input in_lsb_io_in,

 
 
    // for alu to calculate
    output reg [`OPENUM_TYPE] out_alu_op, // `NOP means no operations
    output reg [`DATA_TYPE] out_alu_value1,
    output reg [`DATA_TYPE] out_alu_value2,
    output reg [`DATA_TYPE] out_alu_imm,
    output reg [`ROB_POS_TYPE] out_alu_rob_pos,
    output reg [`DATA_TYPE] out_alu_pc,

    // from rob to denote misbranch
    input in_rob_xbp
);
    reg busy[(`RS_SIZE-1):0];
    reg [`ROB_POS_TYPE] robpos[(`RS_SIZE-1):0];
    reg [`OPENUM_TYPE] op[(`RS_SIZE-1):0];
    reg [`DATA_TYPE] value1[(`RS_SIZE-1):0];
    reg [`DATA_TYPE] value2[(`RS_SIZE-1):0];
    reg [`DATA_TYPE] imms [(`RS_SIZE-1):0];
    reg [`DATA_TYPE] pcs [(`RS_SIZE-1):0];
    reg [`ROB_POS_TYPE] value1_tag[(`RS_SIZE-1):0];
    reg [`ROB_POS_TYPE] value2_tag[(`RS_SIZE-1):0];

    wire [`RS_ID_TYPE] free_tag;
    wire [`RS_ID_TYPE] issue_tag;
    wire ready [(`RS_SIZE-1):0];
    
    assign out_fetcher_idle=(free_tag!=`ZERO_RS);
    assign free_tag = ~busy[1] ? 1 :
                            ~busy[2] ? 2 : 
                            ~busy[3] ? 3 :
                            ~busy[4] ? 4 :
                            ~busy[5] ? 5 : 
                            ~busy[6] ? 6 :
                            ~busy[7] ? 7 :
                            ~busy[8] ? 8 : 
                            ~busy[9] ? 9 :
                            ~busy[10] ? 10 :
                            ~busy[11] ? 11 :
                            ~busy[12] ? 12 :
                            ~busy[13] ? 13 :
                            ~busy[14] ? 14 : 
                            ~busy[15] ? 15 : `ZERO_RS;

    genvar j;
    //check ready=busy and Qi=Qj=0
    generate
        for(j = 1;j < `RS_SIZE;j=j+1) begin:check_readiness
            assign ready[j] = (busy[j] == `TRUE) && (value1_tag[j]==`ZERO_ROB) && (value2_tag[j]==`ZERO_ROB);
        end
    endgenerate
    assign issue_tag = ready[1] ? 1 : 
                        ready[2] ? 2 : 
                        ready[3] ? 3 :
                        ready[4] ? 4 :
                        ready[5] ? 5 :
                        ready[6] ? 6 :
                        ready[7] ? 7 : 
                        ready[8] ? 8 : 
                        ready[9] ? 9 :
                        ready[10] ? 10 :
                        ready[11] ? 11 :
                        ready[12] ? 12 :
                        ready[13] ? 13 :
                        ready[14] ? 14 :
                        ready[15] ? 15 : `ZERO_RS;

integer i;
    always @(posedge clk ) begin

        if(rst)begin
            out_alu_op <= `OPENUM_NOP;
            for(i = 1;i < `RS_SIZE;i=i+1) begin 
                op[i] <= `OPENUM_NOP;
                busy[i] <= `FALSE;
            end
        end 
        if(rst==`FALSE&&rdy)begin
            out_alu_op<=`OPENUM_NOP;
            if(in_rob_xbp==`FALSE)begin
                if(issue_tag!=`ZERO_RS)begin
                    out_alu_op<=op[issue_tag];
                    out_alu_value1<=value1[issue_tag];
                    out_alu_value2<=value2[issue_tag];
                    out_alu_rob_pos<=robpos[issue_tag];
                    out_alu_imm<=imms[issue_tag];
                    out_alu_pc<=pcs[issue_tag];
                    busy[issue_tag]<=`FALSE;
                end
                //suck in new entries
                if(in_fetcher_flag==`TRUE&&in_decoder_op!=`OPENUM_NOP&&in_decoder_rob!=`ZERO_ROB)begin
                    op[free_tag]<=in_decoder_op;
                    robpos[free_tag]<=in_decoder_rob;
                    value1[free_tag]<=in_decoder_value1;
                    value2[free_tag]<=in_decoder_value2;
                    imms[free_tag]<=in_decoder_imm;
                    value1_tag[free_tag]<=in_decoder_tag1;
                    value2_tag[free_tag]<=in_decoder_tag2;
                    pcs[free_tag]<=in_decoder_pc;
                    busy[free_tag]<=`TRUE;

                    if(in_alu_cdb_pos!=`ZERO_ROB)begin
                        if(in_alu_cdb_pos==in_decoder_tag1)begin
                            // $display($time," [RS] quick forwarding happens",in_alu_cdb_pos);
         
                            value1[free_tag]<=in_alu_cdb_value;
                            value1_tag[free_tag]<=`ZERO_ROB;
                        end
                        if(in_alu_cdb_pos==in_decoder_tag2)begin
                            value2[free_tag]<=in_alu_cdb_value;
                            value2_tag[free_tag]<=`ZERO_ROB;
                        end
                    end
                    if(in_lsb_cdb_pos!=`ZERO_ROB&&in_lsb_io_in==`FALSE)begin
                        if(in_lsb_cdb_pos==in_decoder_tag1)begin
                            value1[free_tag]<=in_lsb_cdb_value;
                            value1_tag[free_tag]<=`ZERO_ROB;
                        end
                        if(in_lsb_cdb_pos==in_decoder_tag2)begin
                            value2[free_tag]<=in_lsb_cdb_value;
                            value2_tag[free_tag]<=`ZERO_ROB;
                        end
                    end
                end


                for(i = 1;i < `RS_SIZE;i=i+1) begin 
                    if(busy[i] == `TRUE) begin 
                        if(in_alu_cdb_pos != `ZERO_ROB) begin  
                            if(value1_tag[i] == in_alu_cdb_pos) begin 
                                value1[i] <= in_alu_cdb_value;
                                value1_tag[i] <= `ZERO_ROB;
                            end
                            if(value2_tag[i] == in_alu_cdb_pos) begin 
                                value2[i] <= in_alu_cdb_value;
                                value2_tag[i] <= `ZERO_ROB;
                            end
                        end
                        if(in_rob_cdb_pos != `ZERO_ROB) begin  
                            if(value1_tag[i] == in_rob_cdb_pos) begin 
                                value1[i] <= in_rob_cdb_value;
                                value1_tag[i] <= `ZERO_ROB;
                            end
                            if(value2_tag[i] == in_rob_cdb_pos) begin 
                                value2[i] <= in_rob_cdb_value;
                                value2_tag[i] <= `ZERO_ROB;
                            end
                        end
                        if(in_lsb_cdb_pos != `ZERO_ROB && in_lsb_io_in == `FALSE) begin 
                            if(value1_tag[i] == in_lsb_cdb_pos) begin 
                                value1[i] <= in_lsb_cdb_value;
                                value1_tag[i] <= `ZERO_ROB;
                            end
                            if(value2_tag[i] == in_lsb_cdb_pos) begin 
                                value2[i] <= in_lsb_cdb_value;
                                value2_tag[i] <= `ZERO_ROB;
                            end
                        end
                    end
                end
            end else begin
                //rob result misbranch, flush
                for(i=0;i<`RS_SIZE;i=i+1)begin
                    busy[i]<=`FALSE;
                    robpos[i]<=`ZERO_ROB;
                end
            end
        
        
        
        end

    end
endmodule