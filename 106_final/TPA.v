module TPA(clk, reset_n, 
	   SCL, SDA, 
	   cfg_req, cfg_rdy, cfg_cmd, cfg_addr, cfg_wdata, cfg_rdata);
input 		clk; 
input 		reset_n;
// Two-Wire Protocol slave interface 
input 		SCL;  // SCL = clk
inout		SDA;

// Register Protocal Master interface 
input		cfg_req;
output		cfg_rdy;
input		cfg_cmd;
input	[7:0]	cfg_addr;
input	[15:0]	cfg_wdata;
output	[15:0]  cfg_rdata;

reg	[15:0] Register_Spaces	[0:255];

// ===== Coding your RTL below here ================================= 

parameter S_RIM_IDLE = 0;
parameter S_RIM_WR   = 1;
parameter S_RIM_RD   = 2;

parameter S_TWP_IDLE 	  = 0;
parameter S_TWP_WR_addr   = 1;
parameter S_TWP_WR_data   = 2;
parameter S_TWP_RD_addr   = 3;
parameter S_TWP_RD_data   = 4;
parameter S_TWP_prepare   = 5;
parameter S_TWP_TAR_1     = 6;
parameter S_TWP_TAR_2     = 7;

integer i, j;

reg [2:0] state_RIM_r, state_RIM_w, state_TWP_r, state_TWP_w;
reg [7:0] TWP_addr_r, TWP_addr_w;
reg [15:0] TWP_data_r, TWP_data_w, cfg_rdata_r, cfg_rdata_w;
reg [2:0] addr_cnt_r, addr_cnt_w;
reg [3:0] data_cnt_r, data_cnt_w;
reg [2:0] TAR_cnt_r, TAR_cnt_w;
reg cfg_rdy_r, cfg_rdy_w, SDA_r, SDA_w;
reg RIM_WR_flag_r, RIM_WR_flag_w;
reg [7:0] cfg_addr_buffer_r, cfg_addr_buffer_w;
reg RIM_cnt_r, RIM_cnt_w;

assign cfg_rdy = cfg_rdy_r;
assign cfg_rdata = cfg_rdata_w;
assign SDA = (state_TWP_r == S_TWP_TAR_1 || state_TWP_r == S_TWP_RD_data || state_TWP_r == S_TWP_TAR_2) ? SDA_r : 1'bz;

// FSM of RIM
always @(*) begin
	state_RIM_w = state_RIM_r;
	cfg_rdy_w = cfg_rdy_r;
	cfg_rdata_w = cfg_rdata_r;
	case (state_RIM_r)
		S_RIM_IDLE: begin
			if(cfg_req && cfg_cmd) begin
				state_RIM_w = S_RIM_WR;
				cfg_rdy_w = 1;
			end 
			else if(cfg_req && !cfg_cmd) begin
				state_RIM_w = S_RIM_RD;
				cfg_rdy_w = 1;
			end
			else state_RIM_w = state_RIM_r;
		end 
		S_RIM_WR: begin
			state_RIM_w = (RIM_cnt_r) ? S_RIM_IDLE : S_RIM_WR;
			cfg_rdy_w = (RIM_cnt_r) ? 0 : 1;
		end
		S_RIM_RD: begin
			state_RIM_w = (RIM_cnt_r) ? S_RIM_IDLE : S_RIM_RD;
			cfg_rdata_w = Register_Spaces[cfg_addr];
			cfg_rdy_w = (RIM_cnt_r) ? 0 : 1;
		end
	endcase
end

// FSM of TWP
always @(*) begin
	state_TWP_w = state_TWP_r;
	RIM_WR_flag_w = RIM_WR_flag_r;
	cfg_addr_buffer_w = cfg_addr_buffer_r;
	TWP_addr_w = TWP_addr_r;
	TWP_data_w = TWP_data_r;
	SDA_w = 1'bz;
	case (state_TWP_r)
		S_TWP_IDLE: begin
			TWP_addr_w = 8'd0;
			TWP_data_w = 16'd0;
			RIM_WR_flag_w = 0;
			cfg_addr_buffer_w = 8'd0;
			if(!SDA) begin
				state_TWP_w = S_TWP_prepare;
			end
		end 
		S_TWP_prepare: begin
			if(SDA) begin
				state_TWP_w = S_TWP_WR_addr;
				if(state_RIM_r == S_RIM_WR && !RIM_cnt_r) begin // WR at the same time
					RIM_WR_flag_w = 1;
					cfg_addr_buffer_w = (!RIM_WR_flag_r) ? cfg_addr : cfg_addr_buffer_r; // record RIM WR address
				end
			end
			else begin
				state_TWP_w = S_TWP_RD_addr;
			end
		end
		S_TWP_WR_addr: begin
			state_TWP_w = (addr_cnt_r == 3'd7) ? S_TWP_WR_data : S_TWP_WR_addr;
			TWP_addr_w[addr_cnt_r] = SDA;
			if(state_RIM_r == S_RIM_WR) begin // RIM WR after TWP
				RIM_WR_flag_w = 1;
				cfg_addr_buffer_w = (!RIM_WR_flag_r) ? cfg_addr : cfg_addr_buffer_r;; // record RIM WR address
			end
		end
		S_TWP_WR_data: begin
			if((state_RIM_w == S_RIM_WR && TWP_addr_r == cfg_addr) || (RIM_WR_flag_r && TWP_addr_r == cfg_addr_buffer_r)) begin
				state_TWP_w = S_TWP_IDLE;
			end
			else begin
				state_TWP_w = (data_cnt_r == 4'd15) ? S_TWP_IDLE : S_TWP_WR_data;
				TWP_data_w[data_cnt_r] = SDA;
			end
		end
		S_TWP_RD_addr: begin
			state_TWP_w = (addr_cnt_r == 3'd7) ? S_TWP_TAR_1 : S_TWP_RD_addr;
			TWP_addr_w[addr_cnt_r] = SDA;
		end
		S_TWP_TAR_1: begin
			state_TWP_w = (TAR_cnt_r == 3'd4) ? S_TWP_RD_data : S_TWP_TAR_1;
			case (TAR_cnt_r)
				1: SDA_w = 1;
				2: SDA_w = 1;
				3: SDA_w = 0;
				4: SDA_w = Register_Spaces[TWP_addr_r][0]; // WR data LSB
			endcase
		end
		S_TWP_RD_data: begin
			state_TWP_w = (data_cnt_r == 4'd15) ? S_TWP_TAR_2 : S_TWP_RD_data;
			SDA_w = Register_Spaces[TWP_addr_r][data_cnt_r];
		end
		S_TWP_TAR_2: begin
			state_TWP_w = S_TWP_IDLE;
		end
	endcase
end

// RIM write counter
always @(*) begin
	RIM_cnt_w = RIM_cnt_r;
	case (state_RIM_r)
		S_RIM_WR: RIM_cnt_w = (RIM_cnt_r) ? 0 : 1;
		S_RIM_RD: RIM_cnt_w = (RIM_cnt_r) ? 0 : 1;
	endcase
end


// TWP address counter
always @(*) begin
	addr_cnt_w = addr_cnt_r;
	case (state_TWP_r)
		S_TWP_IDLE: addr_cnt_w = 3'd0;
		S_TWP_WR_addr, S_TWP_RD_addr: addr_cnt_w = (addr_cnt_r == 3'd7) ? 3'd0 : addr_cnt_r + 1;
	endcase
end

// TWP TAR counter
always @(*) begin
	TAR_cnt_w = TAR_cnt_r;
	case (state_TWP_r)
		S_TWP_IDLE: TAR_cnt_w = 3'd0;
		S_TWP_TAR_1 : TAR_cnt_w = (TAR_cnt_r == 3'd4) ? 3'd0 : TAR_cnt_r + 1;
	endcase
end

// TWP data counter
always @(*) begin
	data_cnt_w = data_cnt_r;
	case (state_TWP_r)
		S_TWP_IDLE: data_cnt_w = 4'd0;
		S_TWP_TAR_1 : data_cnt_w = (TAR_cnt_r == 3'd4) ? 4'd1 : 4'd0;
		S_TWP_WR_data, S_TWP_RD_data : data_cnt_w = (data_cnt_r == 4'd15) ? 4'd0 : data_cnt_r + 1;
	endcase
end

// write register spaces
always @(posedge clk or negedge reset_n) begin
	if(!reset_n) begin
		for(i=0;i<256;i=i+1) begin
			Register_Spaces[i] <= 16'd0;
		end
	end
	else begin
		if(state_RIM_r == S_RIM_WR) begin
			Register_Spaces[cfg_addr] <= cfg_wdata;
		end
		else if(state_TWP_r == S_TWP_WR_data && data_cnt_r == 4'd15) begin
			Register_Spaces[TWP_addr_r] <= {SDA, TWP_data_r[14:0]};
		end
	end
end


// sequential
always @(posedge clk or negedge reset_n) begin
	if(!reset_n) begin
		state_RIM_r   <= S_RIM_IDLE;
		state_TWP_r   <= S_TWP_IDLE;
		cfg_rdy_r     <= 0;
		TWP_addr_r    <= 8'd0;
		TWP_data_r    <= 16'd0;
		cfg_rdata_r   <= 16'd0;
		RIM_WR_flag_r <= 0;
		cfg_addr_buffer_r <= 8'd0;
		addr_cnt_r	  <= 3'd0;
		TAR_cnt_r     <= 2'd0;
		data_cnt_r    <= 4'd0;
		RIM_cnt_r  <= 0;
	end
	else begin
		state_RIM_r   <= state_RIM_w;
		state_TWP_r   <= state_TWP_w;
		cfg_rdy_r     <= cfg_rdy_w;
		TWP_addr_r    <= TWP_addr_w;
		TWP_data_r    <= TWP_data_w;
		cfg_rdata_r   <= cfg_rdata_w;
		RIM_WR_flag_r <= RIM_WR_flag_w;
		cfg_addr_buffer_r <= cfg_addr_buffer_w;
		addr_cnt_r 	  <= addr_cnt_w;
		TAR_cnt_r     <= TAR_cnt_w;
		data_cnt_r    <= data_cnt_w;
		RIM_cnt_r  <= RIM_cnt_w;
	end
end

always @(negedge SCL or negedge reset_n) begin
	if(!reset_n) begin
		SDA_r <= 1'bz;
	end
	else begin
		SDA_r <= SDA_w;
	end
end

endmodule
