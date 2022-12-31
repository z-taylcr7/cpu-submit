
//Hello everyone, I'm a self-trained mem Ctrler having been training for two and a half year.
//I can do nothing but:
//                      Chang
//                      Tiao
//                      Rap
//                      Lanqiu
//Now, let's have some music!!!!!
module memCtrl(
    input clk,input rst,input rdy,
    
    // check uart is full
    input in_uart_full, // 1 if uart buffer is full

    // from fetcher to get instruction
    input in_fetcher_flag,
    input [`DATA_TYPE] in_fetcher_addr,

    // to fetcher to make read enable 
    output reg out_fetcher_flag,

    // from lsb to read memory 
    input in_lsb_flag,
    input [`DATA_TYPE] in_lsb_addr,
    input [5:0] in_lsb_size,
    input in_lsb_sign,

    // to lsb to make read enable 
    output reg out_lsb_flag,

    // from rob to write memory 
    input in_rob_flag,
    input [`DATA_TYPE] in_rob_addr,
    input [5:0] in_rob_size,
    input [`DATA_TYPE] in_rob_data,

    // from rob to load io 
    input in_rob_load_flag,

    //to rob to make read enable
    output reg out_rob_flag,

    // output data bus 
    output reg [`DATA_TYPE] out_data,

    // interface with ram  
    output reg out_ram_write_flag,      
    output reg [`DATA_TYPE] out_ram_address,
    output reg [7:0] out_ram_data,
    input [7:0] in_ram_data,

    // from rob to denote xbp 
    input in_rob_xbp
);
    localparam IDLE = 0,FETCHER_READ = 1,LSB_READ = 2,ROB_WRITE = 3,IO_READ = 4;
    
    wire [2:0] buffered_status; // 0 for idle ; 1 for fetcher; 2 for lsb; 3 for rob write; 4 for rob read
    wire [`MEMPORT_TYPE] buffered_write_data;
    wire disable_to_write;
    reg [1:0] wait_uart; // wait 2 cycle for uart_full signal reg fetcher_flag;
    reg lsb_flag;
    reg rob_flag;
    reg io_flag;
    reg fetcher_flag;
    reg [5:0] stages;
    reg [2:0] status;
   

    // Write Buffer Control
    wire wb_is_empty;
    wire wb_is_full;
    reg [`WB_TAG] head;
    reg [`WB_TAG] tail;
    reg [`DATA_TYPE] wb_data [(`BUFFER_SIZE-1):0];
    reg [`DATA_TYPE] wb_addr [(`BUFFER_SIZE-1):0];
    reg [5:0] BUFFER_Size [(`BUFFER_SIZE-1):0];
    wire [`WB_TAG] nextPtr = (tail + 1) % (`BUFFER_SIZE);
    wire [`WB_TAG] nowPtr = (head + 1) % (`BUFFER_SIZE);
    assign wb_is_empty = (head == tail) ? `TRUE : `FALSE;
    assign wb_is_full = (nextPtr == head) ? `TRUE : `FALSE;
    assign disable_to_write = (in_uart_full == `TRUE || wait_uart != 0 ) && (wb_addr[nowPtr][17:16] == 2'b11);
    wire test;
    wire lsblsbflag;
    assign test=(in_rob_flag)?`TRUE:`FALSE;
    // Combinatorial logic
    assign buffered_status = (io_flag == `TRUE) ? IO_READ :
                                (wb_is_empty == `FALSE) ? ROB_WRITE : 
                                    (lsb_flag == `TRUE) ? LSB_READ : 
                                        (fetcher_flag == `TRUE) ? FETCHER_READ : IDLE;

    assign buffered_write_data = (stages == 0) ? 0 :
                                    (stages == 1) ? wb_data[nowPtr][7:0] :
                                        (stages == 2) ? wb_data[nowPtr][15:8] : 
                                            (stages == 3) ? wb_data[nowPtr][23:16] : wb_data[nowPtr][31:24];
    // Temporal logic
    always @(posedge clk) begin 
                    
        if(rst == `TRUE) begin 
            fetcher_flag <= `FALSE;
            out_fetcher_flag <= `FALSE;
            lsb_flag <= `FALSE;
            out_lsb_flag <= `FALSE;
            rob_flag <= `FALSE;
            out_rob_flag <= `FALSE;
            out_data <= `ZERO_WORD;
            status <= IDLE;
            stages <= 1;
            out_ram_write_flag <= 0;
            out_ram_address <= `ZERO_WORD;
            head <= 0;
            tail <= 0;
            wait_uart <= 0;
            io_flag <= `FALSE;
        end else if(rdy == `TRUE && (in_rob_xbp == `FALSE || status == ROB_WRITE)) begin 
            if(in_rob_xbp == `TRUE) begin 
                fetcher_flag <= `FALSE;
                out_fetcher_flag <= `FALSE;
                lsb_flag <= `FALSE;
                out_lsb_flag <= `FALSE;
                out_rob_flag <= `FALSE;
                out_data <= `ZERO_WORD;
                io_flag <= `FALSE;
            end
            // update buffer
            wait_uart <= wait_uart - ((wait_uart == 0) ? 0 : 1);
            out_ram_write_flag <= 0; // avoid repeatedly writing
            out_rob_flag <= `FALSE;
            out_lsb_flag <= `FALSE;
            out_fetcher_flag <= `FALSE;
            out_ram_data <= 0;
            //out_data <= `ZERO_WORD;
            if(in_rob_load_flag == `TRUE) begin io_flag <= `TRUE; end
            if(in_fetcher_flag == `TRUE) begin fetcher_flag <= `TRUE;end
            if(in_lsb_flag == `TRUE) begin lsb_flag <= `TRUE; end 
            
            if(test == `TRUE || rob_flag == `TRUE) begin  
                if(wb_is_full == `FALSE) begin 
                    rob_flag <= `FALSE;
                    out_rob_flag <= `TRUE;
                    wb_addr[nextPtr] <= in_rob_addr;
                    wb_data[nextPtr] <= in_rob_data;
                    BUFFER_Size[nextPtr] <= in_rob_size;
                    tail <= nextPtr;
                end else begin 
                    rob_flag <= `TRUE; 
                end
            end
            out_ram_address <= out_ram_address + 1;
            stages <= stages + 1;
            case(status)
                IO_READ:begin 
                    case(stages) 
                        1:begin out_ram_address <= `RAM_IO_PORT; end
                        2:begin
                            if(out_ram_address==`ZERO_WORD)begin
                                out_data<=`ZERO_WORD;
                            end else begin
                                
                            out_data <= in_ram_data;
                            end
                            stages <= 1;
                            io_flag <= `FALSE;
                            out_rob_flag <= `TRUE;
                            status <= IDLE;
                        end
                    endcase
                end
                ROB_WRITE:begin 
                    if(disable_to_write == `TRUE) begin
                        out_ram_address <= `ZERO_WORD;
                        out_ram_data <= 0;
                        stages <= 1;
                    end else begin 
                        out_ram_write_flag <= `TRUE;
                        if(stages == 1) begin out_ram_address <= wb_addr[nowPtr]; end
                        out_ram_data <= buffered_write_data;
                        if(stages == BUFFER_Size[nowPtr]) begin
                            head <= nowPtr;
                            stages <= 1;
                            if(nowPtr == tail) begin status <= IDLE; end  
                            else begin 
                                status <= ROB_WRITE;
                                if(wb_addr[nowPtr] == `RAM_IO_PORT) wait_uart <= 2;
                            end
                        end
                    end
                end
                LSB_READ:begin 
                    case(in_lsb_size)
                        1: begin 
                            case(stages) 
                                // 1:begin out_ram_address <= in_lsb_addr; end
                                2:begin
                                    if(in_lsb_sign == `TRUE) begin out_data <= $signed(in_ram_data);end
                                    else begin out_data <= in_ram_data; end
                                    stages <= 1 ;
                                    lsb_flag <= `FALSE;
                                    out_lsb_flag <= `TRUE;
                                    if(wb_is_empty == `FALSE) begin
                                        status <= ROB_WRITE; 
                                        out_ram_address <= `ZERO_WORD;
                                    end else if(fetcher_flag == `TRUE) begin
                                        status <= FETCHER_READ;
                                        out_ram_address <= in_fetcher_addr;
                                    end else begin status <= IDLE; end
                                end
                            endcase
                        end
                        2: begin 
                            case(stages) 
                                // 1: begin out_ram_address <= in_lsb_addr;end 
                                2: begin out_data[7:0] <= in_ram_data; end
                                3: begin 
                                    if(in_lsb_sign) begin out_data <= $signed({in_ram_data,out_data[7:0]}); end
                                    else begin out_data <= {in_ram_data,out_data[7:0]}; end
                                    stages <= 1;
                                    lsb_flag <= `FALSE;
                                    out_lsb_flag <= `TRUE;
                                    if(wb_is_empty == `FALSE) begin
                                        status <= ROB_WRITE; 
                                        out_ram_address <= `ZERO_WORD;
                                    end else if(fetcher_flag == `TRUE) begin
                                        status <= FETCHER_READ;
                                        out_ram_address <= in_fetcher_addr;
                                    end else begin status <= IDLE; end
                                end
                            endcase
                        end
                        4: begin 
                            case(stages) 
                                2: begin out_data[7:0] <= in_ram_data; end
                                3: begin out_data[15:8] <= in_ram_data; end
                                4: begin out_data[23:16] <= in_ram_data; end 
                                5: begin 
                                    out_data[31:24] <= in_ram_data;
                                    stages <= 1;
                                    lsb_flag <= `FALSE;
                                    out_lsb_flag <= `TRUE;
                                    if(wb_is_empty == `FALSE) begin
                                        status <= ROB_WRITE; 
                                        out_ram_address <= `ZERO_WORD;
                                    end else if(fetcher_flag == `TRUE) begin
                                        status <= FETCHER_READ;
                                        out_ram_address <= in_fetcher_addr;
                                    end else begin status <= IDLE; end
                                end 
                            endcase
                        end
                    endcase
                end
                FETCHER_READ:begin
                    case(stages) 
                        2: begin out_data[7:0] <= in_ram_data; end
                        3: begin out_data[15:8] <= in_ram_data; end
                        4: begin out_data[23:16] <= in_ram_data; end 
                        5: begin 
                            out_data[31:24] <= in_ram_data;
                            stages <= 1;
                            fetcher_flag <= `FALSE;
                            out_fetcher_flag <= `TRUE;
                            if(wb_is_empty == `FALSE) begin 
                                status <= ROB_WRITE;
                                out_ram_address <= `ZERO_WORD;
                            end else if(lsb_flag == `TRUE) begin 
                                status <= LSB_READ;
                                out_ram_address <= in_lsb_addr; 
                            end else begin status <= IDLE; end
                        end   
                    endcase
                end
                IDLE: begin 
                    stages <= 1;
                    status <= buffered_status;
                    out_data<=`ZERO_WORD;
                

                    out_ram_address <=  (buffered_status == IO_READ) ? `RAM_IO_PORT :
                                            (buffered_status == ROB_WRITE) ? `ZERO_WORD : 
                                                (buffered_status == LSB_READ) ? in_lsb_addr :
                                                    (buffered_status == FETCHER_READ) ? in_fetcher_addr : `ZERO_WORD;
                end
            endcase
            
        end else if(rdy == `TRUE && in_rob_xbp == `TRUE) begin 
            fetcher_flag <= `FALSE;
            out_fetcher_flag <= `FALSE;
            lsb_flag <= `FALSE;
            out_lsb_flag <= `FALSE;
            out_rob_flag <= `FALSE;
            out_data <= `ZERO_WORD;
            status <= IDLE;
            stages <= 1;
            out_ram_write_flag <= 0;
            out_ram_address <= `ZERO_WORD;
            if(wb_is_empty == `FALSE) begin status <= ROB_WRITE; end
        end
    end

endmodule