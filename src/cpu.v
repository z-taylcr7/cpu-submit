
module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);
//bp to
wire bp_to_fetcher_jump_flag;
//fet to
wire fetcher_to_mem_flag;
wire [`DATA_TYPE] fetcher_to_mem_pc;
wire [`DATA_TYPE] fetcher_to_decoder_inst;
wire [`DATA_TYPE] fetcher_to_decoder_pc;
wire fetcher_to_decoder_jump_flag;
wire [`BP_POS_TYPE] fetcher_to_bp_tag;
wire fetcher_out_store_flag;
//dec to
wire [`REG_POS_TYPE] decoder_to_reg_tag1;
wire [`REG_POS_TYPE] decoder_to_reg_tag2;
wire [`REG_POS_TYPE] decoder_to_reg_dest;
wire [`ROB_POS_TYPE] decoder_to_reg_robtag;
wire [`ROB_POS_TYPE] decoder_to_rob_fetch_tag1;
wire [`ROB_POS_TYPE] decoder_to_rob_fetch_tag2;
wire [`DATA_TYPE] decoder_to_rob_store_dest;
wire [`OPENUM_TYPE] decoder_to_rob_store_op;
wire decoder_to_rob_jump_flag;
wire [`ROB_POS_TYPE] decoder_to_rs_rob_tag;
wire [`OPENUM_TYPE] decoder_to_rs_op;
wire [`DATA_TYPE] decoder_to_rs_value1;
wire [`DATA_TYPE] decoder_to_rs_value2;
wire [`ROB_POS_TYPE] decoder_to_rs_tag1;
wire [`ROB_POS_TYPE] decoder_to_rs_tag2;
wire [`DATA_TYPE] decoder_to_rs_imm;
wire [`DATA_TYPE] decoder_to_rs_pc;
wire [`ROB_POS_TYPE] decoder_to_lsb_rob_tag;
wire [`OPENUM_TYPE] decoder_to_lsb_op;
wire [`DATA_TYPE] decoder_to_lsb_value1;
wire [`DATA_TYPE] decoder_to_lsb_value2;
wire [`ROB_POS_TYPE] decoder_to_lsb_tag1;
wire [`ROB_POS_TYPE] decoder_to_lsb_tag2;
wire [`DATA_TYPE] decoder_to_lsb_imm;
//mem to
wire mem_to_fetcher_flag;
wire mem_to_lsb_flag;
wire mem_to_rob_flag;
wire [`DATA_TYPE] mem_out_data;
//reg to
wire [`DATA_TYPE] reg_to_decoder_value1;
wire [`ROB_POS_TYPE] reg_to_decoder_robtag1;
wire reg_to_decoder_busy1;
wire [`DATA_TYPE] reg_to_decoder_value2;
wire [`ROB_POS_TYPE] reg_to_decoder_robtag2;
wire reg_to_decoder_busy2;
//rs to
wire rs_to_fetcher_idle;
wire [`OPENUM_TYPE] rs_to_alu_op;
wire [`DATA_TYPE] rs_to_alu_value1;
wire [`DATA_TYPE] rs_to_alu_value2;
wire [`DATA_TYPE] rs_to_alu_imm;
wire [`ROB_POS_TYPE] rs_to_alu_rob_tag;
wire [`DATA_TYPE] rs_to_alu_pc;
//lsb to
wire lsb_to_fetcher_idle;
wire [`DATA_TYPE] lsb_out_cdb_value;
wire [`ROB_POS_TYPE] lsb_out_cdb_tag;
wire [`DATA_TYPE] lsb_out_cdb_dest;
wire [`DATA_TYPE] lsb_to_rob_address;
wire lsb_to_mem_flag;
wire [5:0] lsb_to_mem_size;
wire lsb_to_mem_signed;
wire [`DATA_TYPE] lsb_to_mem_address;
wire lsb_out_io_in;
//rob to
wire rob_to_fetcher_idle;
wire rob_out_xbp;
wire [`DATA_TYPE] rob_to_fetcher_newpc;
wire [`ROB_POS_TYPE] rob_to_decoder_freetag;
wire [`DATA_TYPE] rob_to_decoder_fetch_value1;
wire rob_to_decoder_fetch_ready1;
wire [`DATA_TYPE] rob_to_decoder_fetch_value2;
wire rob_to_decoder_fetch_ready2;
wire rob_to_lsb_check;
wire [`REG_POS_TYPE] rob_to_reg_index;
wire [`ROB_POS_TYPE] rob_to_reg_rob_tag;
wire [`DATA_TYPE] rob_to_reg_value;
wire rob_to_mem_flag;
wire [5:0] rob_to_mem_size;
wire [`DATA_TYPE] rob_to_mem_address;
wire [`DATA_TYPE] rob_to_mem_data;
wire rob_to_bp_flag;
wire [`BP_POS_TYPE] rob_to_bp_tag;
wire rob_to_bp_jump_flag;
wire rob_to_mem_load_flag;
wire [`ROB_POS_TYPE] rob_out_tag;
wire [`DATA_TYPE] rob_out_value;
//alu to cdb!
wire [`DATA_TYPE] alu_out_cdb_value;
wire [`ROB_POS_TYPE] alu_out_cdb_tag;
wire [`DATA_TYPE] alu_out_cdb_newpc;

fetcher fet(
  .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
  .out_mem_flag(fetcher_to_mem_flag), .out_mem_pc(fetcher_to_mem_pc),
  .in_mem_flag(mem_to_fetcher_flag), .in_mem_inst(mem_out_data),
  .out_inst(fetcher_to_decoder_inst), .out_pc(fetcher_to_decoder_pc), .out_jump_flag(fetcher_to_decoder_jump_flag),
  .in_rs_idle(rs_to_fetcher_idle), .in_lsb_idle(lsb_to_fetcher_idle), .in_rob_idle(rob_to_fetcher_idle),
  .out_store_flag(fetcher_out_store_flag),
  .out_bp_tag(fetcher_to_bp_tag), .in_bp_jump_flag(bp_to_fetcher_jump_flag),
  .in_rob_xbp(rob_out_xbp), .in_rob_newpc(rob_to_fetcher_newpc)
);
decoder dcd(
  
  .clk(clk_in),.rst(rst_in),.rdy(rdy_in),
  .in_fetcher_instr(fetcher_to_decoder_inst),.in_fetcher_pc(fetcher_to_decoder_pc),.in_fetcher_jump_flag(fetcher_to_decoder_jump_flag),
  .out_reg_tag1(decoder_to_reg_tag1),.in_reg_value1(reg_to_decoder_value1),.in_reg_robtag1(reg_to_decoder_robtag1),.in_reg_busy1(reg_to_decoder_busy1),
  .out_reg_tag2(decoder_to_reg_tag2),.in_reg_value2(reg_to_decoder_value2),.in_reg_robtag2(reg_to_decoder_robtag2),.in_reg_busy2(reg_to_decoder_busy2),
  .out_reg_dest(decoder_to_reg_dest),.out_reg_rob_tag(decoder_to_reg_robtag),
  .in_rob_freetag(rob_to_decoder_freetag),
  .out_rob_fetch_tag1(decoder_to_rob_fetch_tag1), .in_rob_fetch_value1(rob_to_decoder_fetch_value1), .in_rob_fetch_ready1(rob_to_decoder_fetch_ready1), 
  .out_rob_fetch_tag2(decoder_to_rob_fetch_tag2), .in_rob_fetch_value2(rob_to_decoder_fetch_value2), .in_rob_fetch_ready2(rob_to_decoder_fetch_ready2), 
  .out_rob_dest(decoder_to_rob_store_dest),.out_rob_op(decoder_to_rob_store_op),.out_rob_jump_flag(decoder_to_rob_jump_flag),
  .out_rs_rob_tag(decoder_to_rs_rob_tag), .out_rs_op(decoder_to_rs_op), .out_rs_value1(decoder_to_rs_value1), .out_rs_value2(decoder_to_rs_value2),.out_rs_tag1(decoder_to_rs_tag1), .out_rs_tag2(decoder_to_rs_tag2), .out_rs_imm(decoder_to_rs_imm), .out_pc(decoder_to_rs_pc),
  .out_lsb_rob_tag(decoder_to_lsb_rob_tag), .out_lsb_op(decoder_to_lsb_op), .out_lsb_value1(decoder_to_lsb_value1), .out_lsb_value2(decoder_to_lsb_value2), .out_lsb_tag1(decoder_to_lsb_tag1), .out_lsb_tag2(decoder_to_lsb_tag2), .out_lsb_imm(decoder_to_lsb_imm)
  
  );

RS rs(
  .clk(clk_in),.rst(rst_in),.rdy(rdy_in),
  .in_fetcher_flag(fetcher_out_store_flag),
  .out_fetcher_idle(rs_to_fetcher_idle),
  .in_decoder_rob(decoder_to_rs_rob_tag),
  .in_decoder_op(decoder_to_rs_op),
  .in_decoder_value1(decoder_to_rs_value1),
  .in_decoder_value2(decoder_to_rs_value2),
  .in_decoder_imm(decoder_to_rs_imm),
  .in_decoder_tag1(decoder_to_rs_tag1),
  .in_decoder_tag2(decoder_to_rs_tag2),
  .in_decoder_pc(decoder_to_rs_pc),

  .in_alu_cdb_value(alu_out_cdb_value),.in_alu_cdb_pos(alu_out_cdb_tag),
  .in_lsb_cdb_pos(lsb_out_cdb_tag),.in_lsb_cdb_value(lsb_out_cdb_value),
  .in_lsb_io_in(lsb_out_io_in),
  .in_rob_cdb_pos(rob_out_tag), .in_rob_cdb_value(rob_out_value),
  .out_alu_op(rs_to_alu_op), .out_alu_value1(rs_to_alu_value1), .out_alu_value2(rs_to_alu_value2), 
  .out_alu_imm(rs_to_alu_imm), .out_alu_rob_pos(rs_to_alu_rob_tag), .out_alu_pc(rs_to_alu_pc),
  .in_rob_xbp(rob_out_xbp)
);

lsb lsb(
  .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
  .in_fetcher_flag(fetcher_out_store_flag),
  .out_fetcher_isidle(lsb_to_fetcher_idle),
  .in_decoder_rob_tag(decoder_to_lsb_rob_tag), .in_decoder_op(decoder_to_lsb_op), .in_decoder_value1(decoder_to_lsb_value1), .in_decoder_value2(decoder_to_lsb_value2),
  .in_decoder_imm(decoder_to_lsb_imm), .in_decoder_tag1(decoder_to_lsb_tag1), .in_decoder_tag2(decoder_to_lsb_tag2),
  .out_rob_now_addr(lsb_to_rob_address), .in_rob_check(rob_to_lsb_check),
  .in_alu_cdb_tag(alu_out_cdb_tag), .in_alu_cdb_value(alu_out_cdb_value),
  .in_rob_cdb_tag(rob_out_tag), .in_rob_cdb_value(rob_out_value),
  .out_mem_flag(lsb_to_mem_flag), .out_mem_size(lsb_to_mem_size), .out_mem_signed(lsb_to_mem_signed), .out_mem_address(lsb_to_mem_address),
  .in_mem_flag(mem_to_lsb_flag), .in_mem_data(mem_out_data),
  .out_rob_tag(lsb_out_cdb_tag), .out_dest(lsb_out_cdb_dest), .out_value(lsb_out_cdb_value),
  .out_io_in(lsb_out_io_in),
  .in_rob_xbp(rob_out_xbp)
);

rob rob(
  .clk(clk_in), .rst(rst_in), .rdy(rdy_in),

  .out_decoder_idle_tag(rob_to_decoder_freetag),
  .in_decoder_dest(decoder_to_rob_store_dest), .in_decoder_op(decoder_to_rob_store_op), .in_decoder_pc(decoder_to_rs_pc), .in_decoder_jump_flag(decoder_to_rob_jump_flag),
  .in_decoder_fetch_tag1(decoder_to_rob_fetch_tag1), .out_decoder_fetch_value1(rob_to_decoder_fetch_value1), .out_decoder_fetch_ready1(rob_to_decoder_fetch_ready1),
  .in_decoder_fetch_tag2(decoder_to_rob_fetch_tag2), .out_decoder_fetch_value2(rob_to_decoder_fetch_value2), .out_decoder_fetch_ready2(rob_to_decoder_fetch_ready2),
  .out_fetcher_isidle(rob_to_fetcher_idle), .in_fetcher_flag(fetcher_out_store_flag),
  .in_alu_cdb_value(alu_out_cdb_value), .in_alu_cdb_newpc(alu_out_cdb_newpc), .in_alu_cdb_tag(alu_out_cdb_tag),
  .in_lsb_cdb_tag(lsb_out_cdb_tag), .in_lsb_cdb_value(lsb_out_cdb_value), .in_lsb_cdb_dest(lsb_out_cdb_dest),
  .in_lsb_io_in(lsb_out_io_in),.in_lsb_now_addr(lsb_to_rob_address), .out_lsb_check(rob_to_lsb_check),
  .out_reg_index(rob_to_reg_index), .out_reg_rob_tag(rob_to_reg_rob_tag), .out_reg_value(rob_to_reg_value),
  .out_mem_flag(rob_to_mem_flag), .out_mem_size(rob_to_mem_size), .out_mem_address(rob_to_mem_address), .out_mem_data(rob_to_mem_data), .in_mem_flag(mem_to_rob_flag),
  .out_mem_load_flag(rob_to_mem_load_flag), 
  .in_mem_data(mem_out_data),
  .out_xbp(rob_out_xbp), .out_newpc(rob_to_fetcher_newpc),
  .out_bp_flag(rob_to_bp_flag), .out_bp_tag(rob_to_bp_tag), .out_bp_jump_flag(rob_to_bp_jump_flag),
  .out_rob_tag(rob_out_tag), .out_value(rob_out_value)
);
ALU alu(
  .clk(clk_in),.rst(rst_in),.rdy(rdy_in),
  .in_op(rs_to_alu_op),.in_value1(rs_to_alu_value1),.in_value2(rs_to_alu_value2),.in_imm(rs_to_alu_imm),.in_pc(rs_to_alu_pc),.in_rob_tag(rs_to_alu_rob_tag),
  .out_rob_tag(alu_out_cdb_tag),.out_value(alu_out_cdb_value),.out_newpc(alu_out_cdb_newpc)
  );
memCtrl mem(
  .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
  .in_uart_full(io_buffer_full),
  .in_fetcher_flag(fetcher_to_mem_flag), .in_fetcher_addr(fetcher_to_mem_pc),
  .out_fetcher_flag(mem_to_fetcher_flag),
  .in_lsb_flag(lsb_to_mem_flag), .in_lsb_addr(lsb_to_mem_address), .in_lsb_size(lsb_to_mem_size), .in_lsb_sign(lsb_to_mem_sign),
  .out_lsb_flag(mem_to_lsb_flag),
  .in_rob_flag(rob_to_mem_flag), .in_rob_addr(rob_to_mem_address), .in_rob_size(rob_to_mem_size), .in_rob_data(rob_to_mem_data),
  .in_rob_load_flag(rob_to_mem_load_flag),
  .out_rob_flag(mem_to_rob_flag),
  .out_data(mem_out_data),
  .out_ram_write_flag(mem_wr), .out_ram_address(mem_a), .out_ram_data(mem_dout), .in_ram_data(mem_din),
  .in_rob_xbp(rob_out_xbp)
);

regfile regs(
  .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
  .in_fetcher_flag(fetcher_out_store_flag),
  .in_decoder_reg1(decoder_to_reg_tag1), .out_decoder_value1(reg_to_decoder_value1), .out_decoder_rob1(reg_to_decoder_robtag1), .out_decoder_busy1(reg_to_decoder_busy1),
  .in_decoder_reg2(decoder_to_reg_tag2), .out_decoder_value2(reg_to_decoder_value2), .out_decoder_rob2(reg_to_decoder_robtag2), .out_decoder_busy2(reg_to_decoder_busy2),
  .in_decoder_dest_reg(decoder_to_reg_dest), .in_decoder_dest_rob(decoder_to_reg_robtag),
  .in_rob_commit_reg(rob_to_reg_index), .in_rob_commit_rob(rob_to_reg_rob_tag), .in_rob_commit_value(rob_to_reg_value),
  .in_rob_xbp(rob_out_xbp)
);

bp brp(
  .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
  .in_fetcher_tag(fetcher_to_bp_tag),
  .out_fetcher_jump_res(bp_to_fetcher_jump_flag),
  .in_rob_bp_res(rob_to_bp_flag),
  .in_rob_tag(rob_to_bp_tag),
  .in_rob_jump_res(rob_to_bp_jump_flag)
);


// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)



endmodule
