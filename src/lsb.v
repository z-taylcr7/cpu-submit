
module lsb(
    input clk,input rst,input rdy,

    // From fetcher to decide whether to fetch new instruction
    input in_fetcher_flag, 

    // for fetcher to decide whether to fetch new instructions
    output out_fetcher_isidle,

    // from decoder to store entry ,use rob_tag == `ZERO_ROB to decide whether store it in
    input [`ROB_POS_TYPE] in_decoder_rob_tag,
    input [`OPENUM_TYPE] in_decoder_op,
    input [`DATA_TYPE] in_decoder_value1,
    input [`DATA_TYPE] in_decoder_value2,
    input [`DATA_TYPE] in_decoder_imm,
    input [`ROB_POS_TYPE] in_decoder_tag1, 
    input [`ROB_POS_TYPE] in_decoder_tag2,

    //output to ROB to check whether it can be issue to memory
    output [`DATA_TYPE] out_rob_now_addr,
    input in_rob_check, // true for existence of memory address collision and false for none

    //from alu_cdb to update source value 
    input [`ROB_POS_TYPE] in_alu_cdb_tag,
    input [`DATA_TYPE] in_alu_cdb_value,

    // from rob_cdb to update  
    input [`ROB_POS_TYPE] in_rob_cdb_tag,
    input [`DATA_TYPE] in_rob_cdb_value,

    // to memory control 
    output reg out_mem_flag,
    output reg [5:0] out_mem_size,
    output reg out_mem_signed,  // 0 for unsigned;1 for signed
    output reg [`DATA_TYPE] out_mem_address,

    // from memory control 
    input in_mem_flag,
    input [`DATA_TYPE] in_mem_data,

    // CDB to ROB/RS
    output reg [`ROB_POS_TYPE] out_rob_tag, // Zero means Not to do anything
    output reg [`DATA_TYPE] out_dest, // for store 
    output reg [`DATA_TYPE] out_value,
    output reg out_io_in,   // true for 0x30000 read,false for normal load 

    // from ROB to denote that br wrong
    input in_rob_xbp
);
    // Load  寄存器目的地已知，缺地址(x[rs1] + imm) 和 value(from memory)
    // Store 缺目的地(Memory_address: x[rs1] + imm) 和 value(x[rs2])

    // Data structure 
    localparam IDLE = 1'b0,WAIT_MEM = 1'b1;
    reg status; // 0 means idle ; 1 means waiting for memory
    reg busy[(`LSB_SIZE-1):0];
    
    //fifo queueueueue
    reg [`LSB_ID_TYPE] head;
    reg [`LSB_ID_TYPE] tail;
    wire [`LSB_ID_TYPE] nextPtr;
    wire [`LSB_ID_TYPE] nowPtr;

    //addr Storage
    reg [`DATA_TYPE] address [(`LSB_SIZE-1):0];
    reg  address_ready [(`LSB_SIZE-1):0];

    reg [`ROB_POS_TYPE] tags [(`LSB_SIZE-1):0];
    reg [`OPENUM_TYPE] op [(`LSB_SIZE-1):0];
    reg [`DATA_TYPE] imms [(`LSB_SIZE-1):0];
    reg [`ROB_POS_TYPE] value1_tag [(`LSB_SIZE-1):0];
    reg [`ROB_POS_TYPE] value2_tag [(`LSB_SIZE-1):0];
    reg [`DATA_TYPE] value1 [(`LSB_SIZE-1):0];
    reg [`DATA_TYPE] value2 [(`LSB_SIZE-1):0];

    // for address calculation
    wire ready_to_calculate_addr [(`LSB_SIZE-1):0];
    wire [`LSB_ID_TYPE] calculate_tag;
    wire ready_to_issue [(`LSB_SIZE-1):0];
    

    assign nextPtr = tail % (`LSB_SIZE-1) + 1; 
    assign nowPtr = head % (`LSB_SIZE-1) + 1;
    assign out_fetcher_isidle = (nextPtr != head);
    assign out_rob_now_addr = address[nowPtr];

    genvar i;
    generate
        for(i = 1;i < `LSB_SIZE;i=i+1) begin 
            assign ready_to_issue[i] = (busy[i] == `TRUE) && (value2_tag[i] == `ZERO_ROB) && (address_ready[i] == `TRUE);
            assign ready_to_calculate_addr[i] = (busy[i] == `TRUE) && (value1_tag[i] == `ZERO_ROB) && (address_ready[i] == `FALSE);
        end
    endgenerate

    assign calculate_tag = ready_to_calculate_addr[1] ? 1 : 
                        ready_to_calculate_addr[2] ? 2 : 
                        ready_to_calculate_addr[3] ? 3 :
                        ready_to_calculate_addr[4] ? 4 :
                        ready_to_calculate_addr[5] ? 5 :
                        ready_to_calculate_addr[6] ? 6 :
                        ready_to_calculate_addr[7] ? 7 : 
                        ready_to_calculate_addr[8] ? 8 : 
                        ready_to_calculate_addr[9] ? 9 :
                        ready_to_calculate_addr[10] ? 10 :
                        ready_to_calculate_addr[11] ? 11 :
                        ready_to_calculate_addr[12] ? 12 :
                        ready_to_calculate_addr[13] ? 13 :
                        ready_to_calculate_addr[14] ? 14 :
                        ready_to_calculate_addr[15] ? 15 : `ZERO_LSB;

    integer j;
    always @(posedge clk) begin 
        if(rst == `TRUE) begin 
            ///flushhh
            
            head <= 1; tail <= 1;
            out_rob_tag <= `ZERO_ROB;
            out_mem_flag <= `FALSE;
            out_mem_address <= `ZERO_WORD;
            out_io_in <= `FALSE;
            for(j = 1;j < `LSB_SIZE;j=j+1) begin 
                address_ready[j] <= `FALSE;
                address[j] <= `ZERO_WORD;
                busy[j] <= `FALSE;
            end
            status <= IDLE; 
        end else if(rdy == `TRUE && in_rob_xbp == `FALSE) begin
            // Try to issue S/L instruction to ROB:
            out_rob_tag <= `ZERO_ROB;
            out_mem_flag <= `FALSE;
            out_dest <= `ZERO_WORD;
            out_io_in <= `FALSE;
           // $display($time," [ROB] JALR,now_Ptr: ",nowPtr," ready_to_issue:",ready_to_issue[nowPtr], "v2t:",value2_tag[nowPtr]);
                  
            if(ready_to_issue[nowPtr] == `TRUE) begin 
                if(status == IDLE) begin 
                     case(op[nowPtr])
                        `OPENUM_SB,`OPENUM_SH,`OPENUM_SW: begin
                            status <= IDLE;
                            out_dest <= address[nowPtr];
                            out_value <= value2[nowPtr];
                            out_rob_tag <= tags[nowPtr];
                            busy[nowPtr] <= `FALSE;
                            address_ready[nowPtr] <= `FALSE;
                            head <= nowPtr;
                        end
                        `OPENUM_LB,`OPENUM_LBU: begin
                            if(address[nowPtr] == `RAM_IO_PORT) begin 
                                status <= IDLE;
                                out_rob_tag <= tags[nowPtr];
                                busy[nowPtr] <= `FALSE;
                                address_ready[nowPtr] <= `FALSE;
                                out_io_in <= `TRUE;
                                head <= nowPtr;
                              //   $display($time, " nowPtr: ",nowPtr,"addr:",address[nowPtr]);
                            end else if(in_rob_check == `FALSE && address[nowPtr] != out_dest) begin
                                status <= WAIT_MEM;
                                out_mem_signed <= (op[nowPtr] == `OPENUM_LB) ? 1 : 0; 
                                out_mem_flag <= `TRUE;
                                out_mem_size <= 1;
                                out_mem_address <= address[nowPtr];
                              //  $display($time, " nowPtr: ",nowPtr,"addr:",address[nowPtr]);
                            end
                        end
                        `OPENUM_LH,`OPENUM_LHU: begin 
                            if(in_rob_check == `FALSE && address[nowPtr] != out_dest) begin
                                status <= WAIT_MEM;
                                out_mem_signed <= (op[nowPtr] == `OPENUM_LH) ? 1 : 0;
                                out_mem_flag <= `TRUE;
                                out_mem_size <= 2;
                                out_mem_address <= address[nowPtr];
                            end
                        end
                        `OPENUM_LW: begin
                            if(in_rob_check == `FALSE && address[nowPtr] != out_dest) begin
                                status <= WAIT_MEM;
                                out_mem_flag <= `TRUE;
                                out_mem_size <= 4;
                                out_mem_address <= address[nowPtr];
                            end
                        end
                    endcase
                end else if(status == WAIT_MEM) begin
                    if(in_mem_flag == `TRUE) begin 
                        // CDB to rs/rob
                        out_rob_tag <= tags[nowPtr];
                        out_value <= in_mem_data;
                        busy[nowPtr] <= `FALSE;
                        address_ready[nowPtr] <= `FALSE;
                        head <= nowPtr;
                        status <= IDLE;
                    end
                end
            end 
            // Calculate effective address per cycle
            if(calculate_tag != `ZERO_LSB) begin 
                address[calculate_tag] <= value1[calculate_tag] + imms[calculate_tag];
                address_ready[calculate_tag] <= `TRUE;
               // $display($time," nowPtr: ",nowPtr, " cal addr: ",value1[calculate_tag],"  ",imms[calculate_tag]);
                
           
            end
            // Store new entry into LSB
            if(in_fetcher_flag == `TRUE && in_decoder_rob_tag != `ZERO_ROB && in_decoder_op != `OPENUM_NOP) begin
                busy[nextPtr] <= `TRUE;
                tail <= nextPtr;
                tags[nextPtr] <= in_decoder_rob_tag;
                op[nextPtr] <= in_decoder_op;
                address_ready[nextPtr] <= `FALSE;
                imms[nextPtr] <= in_decoder_imm;
                value1[nextPtr] <= in_decoder_value1;
                value2[nextPtr] <= in_decoder_value2;
                value1_tag[nextPtr] <= in_decoder_tag1;
                value2_tag[nextPtr] <= in_decoder_tag2;
                // Quick update when CDB Broadcast
                if(in_alu_cdb_tag != `ZERO_ROB) begin 
                    if(in_decoder_tag1 == in_alu_cdb_tag) begin 
                        value1[nextPtr] <= in_alu_cdb_value;
                        value1_tag[nextPtr] <= `ZERO_ROB;
                    end
                    if(in_decoder_tag2 == in_alu_cdb_tag) begin 
                        value2[nextPtr] <= in_alu_cdb_value;
                        value2_tag[nextPtr] <= `ZERO_ROB;
                    end
                end
                if(out_rob_tag != `ZERO_ROB && out_io_in == `FALSE) begin 
                    if(in_decoder_tag1 == out_rob_tag) begin 
                        value1[nextPtr] <= out_value;
                        value1_tag[nextPtr] <= `ZERO_ROB;
                    end
                    if(in_decoder_tag2 == out_rob_tag) begin 
                        value2[nextPtr] <= out_value;
                        value2_tag[nextPtr] <= `ZERO_ROB;
                    end
                end
            end
            
            for(j = 1;j < `LSB_SIZE;j=j+1) begin 
                if(busy[j] == `TRUE) begin 
                    // Monitor ALU CDB
                    if(in_alu_cdb_tag != `ZERO_ROB) begin
                        if(value1_tag[j] == in_alu_cdb_tag) begin 
                            value1[j] <= in_alu_cdb_value;
                            value1_tag[j] <= `ZERO_ROB;
                        end 
                        if(value2_tag[j] == in_alu_cdb_tag) begin 
                            value2[j] <= in_alu_cdb_value;
                            value2_tag[j] <= `ZERO_ROB;
                        end
                    end
                    // Monitor ROB CDB maybe have bugs
                    if(in_rob_cdb_tag != `ZERO_ROB) begin 
                        if(value1_tag[j] == in_rob_cdb_tag) begin 
                            value1[j] <= in_rob_cdb_value;
                            value1_tag[j] <= `ZERO_ROB;
                        end 
                        if(value2_tag[j] == in_rob_cdb_tag) begin 
                            value2[j] <= in_rob_cdb_value;
                            value2_tag[j] <= `ZERO_ROB;
                        end
                    end
                    // Broadcast to itself
                    if(out_rob_tag != `ZERO_ROB && out_io_in == `FALSE) begin 
                        if(value1_tag[j] == out_rob_tag) begin 
                            value1[j] <= out_value;
                            value1_tag[j] <= `ZERO_ROB;
                        end 
                        if(value2_tag[j] == out_rob_tag) begin 
                            value2[j] <= out_value;
                            value2_tag[j] <= `ZERO_ROB;
                        end
                    end
                end
            end

        end else if(rdy == `TRUE && in_rob_xbp == `TRUE) begin 
            //flush
            head <= 1; 
            tail <= 1;
            out_rob_tag <= `ZERO_ROB;
            out_mem_flag <= `FALSE;
            out_mem_address <= `ZERO_WORD;
            out_io_in <= `FALSE;
            for(j = 1;j < `LSB_SIZE;j=j+1) begin 
                address_ready[j] <= `FALSE;
                address[j] <= `ZERO_WORD;
                busy[j] <= `FALSE;
            end
            status <= IDLE; 
        end
    end
endmodule