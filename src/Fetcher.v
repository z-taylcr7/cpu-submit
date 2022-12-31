`include"definition.v"
module fetcher (
    input clk,input rst,input rdy,
    
    // port with mem
    output reg out_mem_flag,
    output reg[`DATA_TYPE] out_mem_pc,

    input in_mem_flag,
    input [`DATA_TYPE] in_mem_inst,

    // info to decoder
    output reg [`DATA_TYPE] out_inst,
    output reg [`DATA_TYPE] out_pc,
    output reg out_jump_flag,

    // RS/LSB/ROB's status
    input in_rs_idle,
    input in_lsb_idle,
    input in_rob_idle,

    // enable rs/lsb/rob to store entry 
    output reg out_store_flag,

    // with bp
    output [`BP_POS_TYPE] out_bp_tag,
    input in_bp_jump_flag,

    // rob may tell bp wrong
    input in_rob_xbp,
    input [`DATA_TYPE] in_rob_newpc

);
    // Control Units
    localparam IDLE = 2'b0,WAIT_MEM = 2'b01,WAIT_IDLE = 2'b10;
    reg [2:0] status; 
    reg [`DATA_TYPE] pc;
    wire next_idle;
    assign next_idle = in_rs_idle && in_lsb_idle && in_rob_idle;

    // I_CACHE
    reg icache_valid [(`ICACHE_SIZE-1):0];
    reg [24:0] icache_tag [(`ICACHE_SIZE-1):0];
    reg [`DATA_TYPE] icache_inst [(`ICACHE_SIZE-1):0];
    
    assign out_bp_tag = pc[9:2];

    integer i;
    always@(posedge clk) begin
        if(rst == `TRUE) begin 
            status <= IDLE;
            pc <= `ZERO_WORD;
            out_inst <= `ZERO_WORD;
            out_store_flag <= `FALSE;
            out_mem_flag <= `FALSE;
            for(i=0;i < `ICACHE_SIZE;i=i+1) begin
                icache_valid[i] <= `FALSE;
            end 
        end else if(rdy == `TRUE) begin 
            
            out_store_flag <= `FALSE;
            out_mem_flag <= `FALSE;
            if(in_rob_xbp == `TRUE) begin 
                status <= IDLE;
                pc <= in_rob_newpc;
            end else begin
                if(status == IDLE) begin
                    // cache hit
                    if(icache_valid[pc[`ICACHE_INDEX_RANGE]] == `TRUE && icache_tag[pc[`ICACHE_INDEX_RANGE]] == pc[`ICACHE_TAG_RANGE]) begin 
                        out_inst <= icache_inst[pc[`ICACHE_INDEX_RANGE]];
                        out_pc <= pc;
                        if(next_idle == `TRUE) begin 
                            out_store_flag <= `TRUE;
                            status <= IDLE;
                            if(icache_inst[pc[`ICACHE_INDEX_RANGE]][`OPCODE_RANGE] == `OPCODE_JAL) begin //JAL
                                pc <= pc + 
                                {
                                    {12{icache_inst[pc[`ICACHE_INDEX_RANGE]][31]}}, 
                                        icache_inst[pc[`ICACHE_INDEX_RANGE]][19:12], 
                                        icache_inst[pc[`ICACHE_INDEX_RANGE]][20], 
                                        icache_inst[pc[`ICACHE_INDEX_RANGE]][30:25], 
                                        icache_inst[pc[`ICACHE_INDEX_RANGE]][24:21], 
                                        1'b0
                                        };
                            end else if(icache_inst[pc[`ICACHE_INDEX_RANGE]][`OPCODE_RANGE] == `OPCODE_BR) begin 
                                if(in_bp_jump_flag == `TRUE) begin 
                                    out_jump_flag <= `TRUE; 
                                    pc <= pc + 
                                    {
                                        {20{icache_inst[pc[`ICACHE_INDEX_RANGE]][31]}},
                                        icache_inst[pc[`ICACHE_INDEX_RANGE]][7],
                                        icache_inst[pc[`ICACHE_INDEX_RANGE]][30:25], 
                                        icache_inst[pc[`ICACHE_INDEX_RANGE]][11:8], 
                                        1'b0
                                      };
                                end else begin 
                                    out_jump_flag <= `FALSE;
                                    pc <= pc + 4;
                                end
                            end else begin pc <= pc + 4; end;
                        end else begin 
                            status <= WAIT_IDLE; 
                        end
                    end else begin  
                        // cache miss
                        status <= WAIT_MEM;
                        out_mem_flag <= `TRUE;
                        out_mem_pc <= pc;
                    end
                end else if(status == WAIT_MEM) begin 
                    if(in_mem_flag == `TRUE) begin 
                        out_pc <= pc;out_inst <= in_mem_inst;
                        // update icache
                        icache_valid[pc[`ICACHE_INDEX_RANGE]] <= `TRUE;
                        icache_tag[pc[`ICACHE_INDEX_RANGE]] <= pc[`ICACHE_TAG_RANGE];
                        icache_inst[pc[`ICACHE_INDEX_RANGE]] <= in_mem_inst;
                        if(next_idle == `TRUE) begin 
                            out_store_flag <= `TRUE;
                            status <= IDLE;
                            if(in_mem_inst[`OPCODE_RANGE] == `OPCODE_JAL) begin 
                                pc <= pc + {
                                    {12{in_mem_inst[31]}}, 
                                    in_mem_inst[19:12], 
                                    in_mem_inst[20], 
                                    in_mem_inst[30:25], 
                                    in_mem_inst[24:21], 
                                    1'b0
                                    };
                            end else if(in_mem_inst[`OPCODE_RANGE] == `OPCODE_BR) begin 
                                if(in_bp_jump_flag == `TRUE) begin 
                                    out_jump_flag <= `TRUE;
                                    pc <= pc + {{20{in_mem_inst[31]}}, in_mem_inst[7], in_mem_inst[30:25], in_mem_inst[11:8], 1'b0};
                                end else begin 
                                    out_jump_flag <= `FALSE;
                                    pc <= pc + 4;
                                end
                            end else begin pc <= pc + 4; end
                        end else begin status <= WAIT_IDLE; end
                    end
                end else if(status == WAIT_IDLE && next_idle == `TRUE) begin 
                    out_store_flag <= `TRUE;
                    status <= IDLE;
                    if(out_inst[`OPCODE_RANGE] == `OPCODE_JAL) begin
                        pc <= pc + {{12{out_inst[31]}}, out_inst[19:12], out_inst[20], out_inst[30:25], out_inst[24:21], 1'b0};
                    end else if(out_inst[`OPCODE_RANGE] == `OPCODE_BR) begin 
                        if(in_bp_jump_flag == `TRUE) begin 
                            out_jump_flag <= `TRUE;
                            pc <= pc + {{20{out_inst[31]}}, out_inst[7], out_inst[30:25], out_inst[11:8], 1'b0};
                        end else begin 
                            out_jump_flag <= `FALSE;
                            pc <= pc + 4;
                        end
                    end else begin pc <= pc + 4; end
                end
            end
        end
    end   
endmodule