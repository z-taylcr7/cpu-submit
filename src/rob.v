`include"definition.v"
module rob(
    input wire clk,
    //rst is currently false!
    input wire rst,
    input wire rdy,
    // asked by decoder about idle tag
    output [`ROB_POS_TYPE] out_decoder_idle_tag,

    // asked by decoder to store entry
    input [`DATA_TYPE] in_decoder_dest, // distinguish register index with memory address
    input [`OPENUM_TYPE] in_decoder_op,
    input [`DATA_TYPE] in_decoder_pc,
    input in_decoder_jump_flag,

    // asked by decoder for register value
    input [`ROB_POS_TYPE] in_decoder_fetch_tag1,
    output [`DATA_TYPE] out_decoder_fetch_value1,
    output out_decoder_fetch_ready1,
    input [`ROB_POS_TYPE] in_decoder_fetch_tag2,
    output [`DATA_TYPE] out_decoder_fetch_value2,
    output out_decoder_fetch_ready2,

    //for fetcher to decide whether to fetch new instruction
    output out_fetcher_isidle,

    // from fetcher to decide whether to store the entry
    input in_fetcher_flag,

    // from alu_cdb
    input [`DATA_TYPE] in_alu_cdb_value,
    input [`DATA_TYPE] in_alu_cdb_newpc,
    input [`ROB_POS_TYPE] in_alu_cdb_tag, // `ZERO_ROB means no data comes in

    // from lsb_cdb
    input [`ROB_POS_TYPE] in_lsb_cdb_tag,
    input [`DATA_TYPE] in_lsb_cdb_value,
    input [`DATA_TYPE] in_lsb_cdb_dest,
    input in_lsb_io_in, // true for io read,false for normal load operation

    // asked by lsb whether exists address collision
    input [`DATA_TYPE] in_lsb_now_addr,
    output out_lsb_check,

    // commit : to register
    output reg[`REG_POS_TYPE] out_reg_index, // zero means there is no data
    output reg[`ROB_POS_TYPE] out_reg_rob_tag,
    output reg[`DATA_TYPE] out_reg_value,

    // commit : to memory 
    output reg out_mem_flag,
    output reg [5:0] out_mem_size,
    output reg [`DATA_TYPE] out_mem_address,
    output reg [`DATA_TYPE] out_mem_data,
    output reg out_mem_load_flag, // for io read
    input in_mem_flag,
    input [`DATA_TYPE] in_mem_data,

    // output denote misbranch  
    output reg out_xbp,
    output reg [`DATA_TYPE] out_newpc,

    //output to BP to modify
    output reg out_bp_flag,
    output reg [`BP_POS_TYPE] out_bp_tag,
    output reg out_bp_jump_flag,

    //output to CDB 
    output reg [`ROB_POS_TYPE] out_rob_tag, // zero means not to do anything
    output reg [`DATA_TYPE] out_value
    );
    localparam IDLE = 0,WAIT_MEM = 1;
    reg status; // 0 means idle and 1 means waiting for memory.

wire [`DATA_TYPE]testval;
assign testval=value[nowPtr];
    // information storage
        reg [`DATA_TYPE] value [(`ROB_SIZE-1):0];
        reg [`DATA_TYPE] dest [(`ROB_SIZE-1):0]; // Registers index is low bits of that
        reg ready [(`ROB_SIZE-1):0];
        reg [`OPENUM_TYPE] op [(`ROB_SIZE-1):0];
        reg [`DATA_TYPE] newpc [(`ROB_SIZE-1):0];
        reg isStore[(`ROB_SIZE-1):0]; // When committed,this tag is canceled. 
        reg isIOread[(`ROB_SIZE-1):0]; // record io load; lbu

        // BP 
        reg [`DATA_TYPE] pcs [(`ROB_SIZE-1):0];
        reg predictions [(`ROB_SIZE-1):0];

        // queue
        reg [`ROB_POS_TYPE] head;
        reg [`ROB_POS_TYPE] tail;
        wire [`ROB_POS_TYPE] nextPtr;
        wire [`ROB_POS_TYPE] nowPtr;
        
        assign nextPtr = tail % (`ROB_SIZE-1)+1;
        assign nowPtr = head % (`ROB_SIZE-1)+1;
        assign out_decoder_idle_tag = (nextPtr == head) ? `ZERO_ROB : nextPtr;
        assign out_fetcher_isidle = (nextPtr != head) 
                                    && ((nextPtr % (`ROB_SIZE-1)+1) != head) 
                                    
                                    ; 
        assign out_decoder_fetch_value1 = value[in_decoder_fetch_tag1];
        assign out_decoder_fetch_ready1 = ready[in_decoder_fetch_tag1];
        assign out_decoder_fetch_value2 = value[in_decoder_fetch_tag2];
        assign out_decoder_fetch_ready2 = ready[in_decoder_fetch_tag2];

        
    assign out_lsb_check = (isStore[1] && in_lsb_now_addr == dest[1])
                        || (isStore[2] && in_lsb_now_addr == dest[2])
                        || (isStore[3] && in_lsb_now_addr == dest[3])
                        || (isStore[4] && in_lsb_now_addr == dest[4])
                        || (isStore[5] && in_lsb_now_addr == dest[5])
                        || (isStore[6] && in_lsb_now_addr == dest[6])
                        || (isStore[7] && in_lsb_now_addr == dest[7])
                        || (isStore[8] && in_lsb_now_addr == dest[8])
                        || (isStore[9] && in_lsb_now_addr == dest[9])
                        || (isStore[10] && in_lsb_now_addr == dest[10])
                        || (isStore[11] && in_lsb_now_addr == dest[11])
                        || (isStore[12] && in_lsb_now_addr == dest[12])
                        || (isStore[13] && in_lsb_now_addr == dest[13])
                        || (isStore[14] && in_lsb_now_addr == dest[14])
                        || (isStore[15] && in_lsb_now_addr == dest[15]);
    integer i;
        always @(posedge clk ) begin
            if(rst==`TRUE)begin
                head <= 1; tail <= 1;
                out_reg_index <= `ZERO_REG;
                out_mem_flag <= `FALSE;
                out_mem_load_flag <= `FALSE;
                status <= IDLE;
                out_xbp <= `FALSE;
                out_bp_flag <= `FALSE;
                out_rob_tag <= `ZERO_ROB;
                for(i = 0;i < `ROB_SIZE;i=i+1) begin 
                    ready[i] <= `FALSE;
                    isStore[i] <= `FALSE;
                    isIOread[i] <= `FALSE;
                end
            end else if(rdy==`TRUE && out_xbp==`FALSE)begin
                out_reg_index<=`ZERO_REG;
                out_reg_value<=`ZERO_WORD;
                out_rob_tag<=`ZERO_ROB;
                out_mem_flag=`FALSE;
                out_mem_load_flag<=`FALSE;
                out_bp_flag<=`FALSE;
                if(in_fetcher_flag==`TRUE&&in_decoder_op!=`OPENUM_NOP)begin
                    //store new entries
                    
                   // $display($time," [ROB]New entry tag : ",nextPtr," opcode: %b",in_decoder_op,"; PC : %h",in_decoder_pc );
                
                    predictions[nextPtr] <= in_decoder_jump_flag;
                    dest[nextPtr] <= in_decoder_dest;
                    op[nextPtr] <= in_decoder_op;
                    pcs[nextPtr]<=in_decoder_pc;
                    value[nextPtr]<=`ZERO_WORD;
                    if(in_decoder_op==`OPENUM_SB||in_decoder_op==`OPENUM_SH||in_decoder_op==`OPENUM_SW)begin
                        isStore[nextPtr]<=`TRUE;
                    end else begin
                        isStore[nextPtr]<=`FALSE;
                    end
                    ready[nextPtr]<=`FALSE;
                    tail<=nextPtr;
                end 
                if(in_lsb_cdb_tag != `ZERO_ROB) begin
                    ready[in_lsb_cdb_tag] <= (in_lsb_io_in == `TRUE) ? `FALSE : `TRUE;
                    value[in_lsb_cdb_tag] <= in_lsb_cdb_value;
                    isIOread[in_lsb_cdb_tag] <= (in_lsb_io_in == `TRUE) ? `TRUE : `FALSE;
                    if(isStore[in_lsb_cdb_tag]) begin 
                            dest[in_lsb_cdb_tag] <= in_lsb_cdb_dest;
                        end    
                end
                if(in_alu_cdb_tag != `ZERO_ROB) begin
                    value[in_alu_cdb_tag] <= in_alu_cdb_value;
                    newpc[in_alu_cdb_tag] <= in_alu_cdb_newpc;
                    ready[in_alu_cdb_tag] <= `TRUE;    
                end
                //commit! now!
                if(ready[nowPtr]==`TRUE&&head!=tail)begin
                    if(status==IDLE)begin
                        $display($time," [ROB] Start Committing : ",nowPtr," opcode: %b",op[nowPtr], " pc: %h",pcs[nowPtr]);
                   //     if(op[nowPtr]==`OPENUM_JALR) $display($time," [ROB] newpc= ",newpc[nowPtr]," opcode: %b",op[nowPtr], " newpc: %h",newpc[nowPtr]);
                                
                        case (op[nowPtr])
                            `OPENUM_NOP:begin
                                //nothing
                            end 
                            `OPENUM_JALR:begin
                            
                                out_reg_index<=dest[nowPtr][`REG_POS_TYPE];
                                out_reg_value<=value[nowPtr];
                                out_reg_rob_tag<=nowPtr;
                                out_newpc<=newpc[nowPtr];
                                out_xbp<=`TRUE;
                            end
                            // `OPENUM_JAL:begin
                            //          $display($time,"big problem");
                                
                            // end
                            `OPENUM_BEQ,`OPENUM_BLT,`OPENUM_BLTU,`OPENUM_BNE,`OPENUM_BGE,`OPENUM_BGEU:begin
                                out_bp_flag<=`TRUE;
                                isStore[nowPtr] <= `FALSE;
                                head <= nowPtr;
                                out_bp_tag<=pcs[nowPtr][9:2];
                                status <= IDLE;
                                if(value[nowPtr]==`JUMP_ENABLE)begin
                                   out_bp_jump_flag<=`TRUE;
                                    if(predictions[nowPtr]==`FALSE)begin
                                       
                                   // $display($time," [ROB] Misbranch should jump: ",nowPtr," opcode: %b",op[nowPtr], " newpc: %h",newpc[nowPtr]);
                                
                                      out_xbp<=`TRUE;
                                        out_newpc<=newpc[nowPtr];                                
                                    end
                                end else begin
                                    
                                     out_bp_jump_flag<=`FALSE;
                                    if(predictions[nowPtr]==`TRUE)begin
                                     
                                 //   $display($time," [ROB] Misbranch shouldnot jump rob_tag: ",nowPtr," opcode: %b",op[nowPtr], " newpc: %h",pcs[nowPtr] + 4);
                                   out_xbp<=`TRUE;
                                        out_newpc<=pcs[nowPtr]+`NEXT_PC;                                
                                    end
                                end
                            end
                            `OPENUM_SB:begin
                                status <= WAIT_MEM;
                                out_mem_size <= 1;
                                out_mem_address <= dest[nowPtr];
                                out_mem_data <= value[nowPtr];
                                out_mem_flag <= `TRUE;
                            end
                            `OPENUM_SH:begin
                                status <= WAIT_MEM;
                                out_mem_size <= 2;
                                out_mem_address <= dest[nowPtr];
                                out_mem_data <= value[nowPtr];
                                out_mem_flag <= `TRUE;
                            end
                            `OPENUM_SW:begin
                                status <= WAIT_MEM;
                                out_mem_size <= 4;
                                out_mem_address <= dest[nowPtr];
                                out_mem_data <= value[nowPtr];
                                out_mem_flag <= `TRUE;
                            end
                            default: begin
                                isStore[nowPtr]<=`FALSE;
                                out_reg_index<=dest[nowPtr][`REG_POS_TYPE];
                                out_reg_value<=value[nowPtr];
                                out_reg_rob_tag<=nowPtr;

                                head <= nowPtr;
                                status<=IDLE;
                            end
                        endcase
                    end
                    else if(status == WAIT_MEM) begin 
                        if(in_mem_flag == `TRUE) begin
                              status <= IDLE;
                        isStore[nowPtr] <= `FALSE;  
                        head <= nowPtr;
                       //$display($time," [ROB] Finish storing memory, rob tag : ",nowPtr," ;PC : %h ",pcs[nowPtr]," ;value :%o",value[nowPtr]," ;Address : %h",dest[nowPtr]);
                       
                        end 
                    end 
                end
            else if(isIOread[nowPtr] == `TRUE && head != tail) begin 
                if(status == IDLE) begin
                    status <= WAIT_MEM;
                    out_mem_load_flag <= `TRUE;
                     //$display($time," [ROB] Start IO_READ : ",nowPtr," opcode: %b",op[nowPtr], " pc: %h",pcs[nowPtr]," ready : ",ready[nowPtr]);
                end else if(status == WAIT_MEM) begin 
                    if(in_mem_flag == `TRUE) begin 
                       // $display($time," [ROB] Finish IO_READ : ",nowPtr, " pc: %h",pcs[nowPtr]," data : %o",in_mem_data);
                        status <= IDLE;                            
                        out_reg_index <= dest[nowPtr][`REG_POS_TYPE];
                        out_reg_rob_tag <= nowPtr;
                        out_reg_value <= in_mem_data;
                        value[nowPtr] <= in_mem_data;
                        ready[nowPtr] <= `TRUE;
                        isStore[nowPtr] <= `FALSE;
                        isIOread[nowPtr] <= `FALSE;
                        head <= nowPtr;
                        // broadcast
                        out_rob_tag <= nowPtr;
                        out_value <= in_mem_data;
                    end
                end
            end
        end else if(rdy == `TRUE && out_xbp == `TRUE) begin
            out_bp_flag <= `FALSE;
            out_rob_tag <= `ZERO_ROB;
            out_mem_load_flag <= `FALSE;
            out_xbp <= `FALSE;
            
            out_reg_index <= `ZERO_REG;
            out_mem_flag <= `FALSE;
            status <= IDLE;
            for(i = 0;i < `ROB_SIZE;i=i+1) begin 
                ready[i] <= `FALSE;
                value[i] <= `ZERO_WORD;
                isStore[i] <= `FALSE;
                isIOread[i] <= `FALSE;
                end
            head <= 1;tail <= 1;
            end
        end
         
endmodule