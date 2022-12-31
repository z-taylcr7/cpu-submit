
module regfile(
     input wire clk,
    //rst is currently false!
    input wire rst,
    input wire rdy,
    // from fetcher to decide whether to update the dest's busy tag 
    input in_fetcher_flag,

    // Decoder asks for Value/ROB-Tag/Busy of two operands
    input [`REG_POS_TYPE] in_decoder_reg1,
    output [`DATA_TYPE] out_decoder_value1,
    output [`ROB_POS_TYPE] out_decoder_rob1,
    output out_decoder_busy1,
    input [`REG_POS_TYPE] in_decoder_reg2,
    output [`DATA_TYPE] out_decoder_value2,
    output [`ROB_POS_TYPE] out_decoder_rob2,
    output out_decoder_busy2,

    // Decoder sets dest register's rob pos
    input [`REG_POS_TYPE] in_decoder_dest_reg,
    input [`ROB_POS_TYPE] in_decoder_dest_rob,

    // accept rob commit
    // commit reg=0 is nothing 
    input [`REG_POS_TYPE] in_rob_commit_reg, 
    input [`ROB_POS_TYPE] in_rob_commit_rob,
    input [`DATA_TYPE] in_rob_commit_value,
    input in_rob_xbp
);
    reg [`DATA_TYPE] values [(`REG_SIZE-1):0];
    reg [`ROB_POS_TYPE] rename [(`REG_SIZE-1):0];
    reg busy [(`REG_SIZE-1):0];

    assign out_decoder_value1 = values[in_decoder_reg1];
    assign out_decoder_rob1 = rename[in_decoder_reg1];
    assign out_decoder_busy1 = busy[in_decoder_reg1];

    assign out_decoder_value2 = values[in_decoder_reg2];
    assign out_decoder_rob2 = rename[in_decoder_reg2];
    assign out_decoder_busy2 = busy[in_decoder_reg2];
  always @(posedge clk) begin
        if(rst == `TRUE) begin
            values[0] <= `ZERO_WORD;
            busy[0] <= `FALSE;
            rename[0] <= `ZERO_ROB;
        end
    end
     
 genvar k;
    generate
        for(k=1;k<`REG_SIZE;k=k+1) begin:ROBWriteReg 
    always @(posedge clk ) begin
        if(rst==`TRUE)begin
            values[k]=`ZERO_WORD;
            rename[k]=`ZERO_ROB;
            busy[k]=`FALSE;
        end 
        if(rdy&&rst==`FALSE)begin
          if(in_rob_commit_reg==k)begin
            values[in_rob_commit_reg]<=in_rob_commit_value;
            if(in_rob_commit_rob==rename[k])begin
                busy[k]<=`FALSE;
            end
          end
          if(in_fetcher_flag==`TRUE && in_decoder_dest_reg==k)begin
            busy[k]<=`TRUE;
            rename[k]<=in_decoder_dest_rob;
            
          end
          if(in_rob_xbp==`TRUE)begin
                busy[k]<=`FALSE;
                rename[k]<=`ZERO_ROB;
          end
        end
    end
        end
    endgenerate

endmodule