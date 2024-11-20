
`timescale 1ns/10ps

module  CONV(
	input				clk,
	input				reset,
	output 				busy,	
	input				ready,	
			
	output reg [11:0]	iaddr,
	input  signed [19:0]idata,	
	
	output reg				cwr,
	output reg [11:0] 	caddr_wr,
	output reg signed[19:0]	cdata_wr, // might need to change to unsigned (3/21 added)
	
	output reg				crd,
	output reg [11:0] 	caddr_rd,
	input  signed[19:0]		cdata_rd, // might need to change to unsigned (3/21 added)
	
	output reg [2:0] 	csel
	);

// my code

reg [2:0] state ,maxpool_step;
reg [3:0] read_index;
reg [11:0] pixel_index;
reg [10:0] write_index;
wire signed[39:0] bias;
assign bias = 40'h0013100000;
// current state
parameter [3:0] state_initial = 0, state_read = 1, state_layer0 = 2, state_layer1 = 3, state_write = 4;

//FSM
always @(posedge clk or posedge reset) begin
	if(reset) state <= state_initial;
	else if(state == state_initial) state <= (!reset)? state_read : state_initial;
	else if(state == state_read) state <= (read_index == 4'd10)?  state_layer0 : state_read;
	else if(state == state_layer0) state <= (pixel_index == 12'd4095)? state_layer1 : state_read;
	else if(state == state_layer1) state <= (maxpool_step == 3'd4)? state_write : state_layer1;
	else if(state == state_write) state <= (write_index == 11'd1024)? state_initial : state_layer1;
	else state <= state_initial;
end


// control signals

always @(posedge clk) begin
	if(state == state_layer0 || state == state_write) cwr <= 1;
	else cwr <= 0;
end

always @(posedge clk) begin
	if(state == state_layer1) crd <= 1;
	else crd <= 0;
end

	
assign busy = (state != state_initial);

always @(posedge clk or posedge reset) begin
	if(reset) csel <= 3'd0;
	else if(state == state_layer0 || state == state_layer1) csel <= 3'd1;
	else if(state == state_write) csel <= 3'd3;
	else csel <= 3'd0;
end

// kernel
wire signed[19:0] kernel [10:0];
assign kernel[0] = 20'h00000;
assign kernel[1] = 20'h00000;
assign kernel[2] = 20'h0A89E;
assign kernel[3] = 20'h092D5;
assign kernel[4] = 20'h06D43;
assign kernel[5] = 20'h01004;
assign kernel[6] = 20'hF8F71;
assign kernel[7] = 20'hF6E54;
assign kernel[8] = 20'hFA6D7;
assign kernel[9] = 20'hFC834;
assign kernel[10] = 20'hFAC19;

// algorithm

// pixel position
wire up = (pixel_index <= 12'd63);
wire down = (pixel_index >= 12'd4032);
wire left = (pixel_index[5:0] == 6'd0);
wire right = (pixel_index[5:0] == 6'd63);

// pixel index
always @(posedge clk or posedge reset) begin
	if(reset) pixel_index <= 12'd0;
	else if(state == state_layer0 && pixel_index == 12'd4095) pixel_index <= 12'd0;
	else if(state == state_layer0) pixel_index <= pixel_index + 1;
	else if(state == state_layer1 && maxpool_step == 3'd4) pixel_index <= (pixel_index[5:0] == 6'd62)? pixel_index + 12'd66 : pixel_index + 12'd2;
	else pixel_index <= pixel_index;
end

// write index
always @(posedge clk or posedge reset) begin
	if(reset) write_index <= 10'd0;
	else if(state == state_write) write_index <= write_index + 1;
	else write_index <= write_index;
end

// maxpool step
always @(posedge clk or posedge reset) begin
	if(reset) maxpool_step <= 3'd0;
	else if(state == state_layer1 && maxpool_step == 3'd4) maxpool_step <= 3'd0;
	else if(state == state_layer1) maxpool_step <= maxpool_step + 1;
	else maxpool_step <= maxpool_step;
end
// read and conv
always @(posedge clk or posedge reset) begin
	if(reset) read_index <= 4'd0;
	else if(state == state_read) read_index <= read_index + 1;
	else read_index <= 4'd0;
end

reg data_valid;
reg signed[19:0] data_temp;
reg signed[39:0] conv_result;

always @(posedge clk or posedge reset) begin
	if(reset) begin
		data_valid <= 1'd0;
		iaddr <= {pixel_index[11:6] - 1'd1, pixel_index[5:0] - 1'd1};
		data_temp <= 20'd0;
		conv_result <= 40'd0;
	end
	else if(state == state_read) begin
		case (read_index)
			4'd0: begin
				if(up || left) data_valid <= 1'd0;
				else begin
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6] - 1'd1, pixel_index[5:0] - 1'd1};
				end
				data_temp <= 20'd0;
				conv_result <= 40'd0;
			end 
			4'd1: begin
				if(up) data_valid <= 1'd0;
				else begin 
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6] - 1'd1, pixel_index[5:0]};
				end
				if(data_valid) data_temp <= idata;
				else data_temp <= 20'd0;
			end
			4'd2: begin
				if(up || right) data_valid <= 1'd0;
				else begin 
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6] - 1'd1, pixel_index[5:0] + 1'd1};
				end
				if(data_valid) begin 
					data_temp <= idata;
				end
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];
			end 
			4'd3: begin
				if(left) data_valid <= 1'd0;
				else begin 
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6], pixel_index[5:0] - 1'd1};
				end
				if(data_valid) begin 
					data_temp <= idata;
				end
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];
			end 
			4'd4: begin
				data_valid <= 1'd1;
				iaddr <= {pixel_index[11:6], pixel_index[5:0]};
				if(data_valid) begin 
					data_temp <= idata;
				end
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];
			end 
			4'd5: begin
				if(right) data_valid <= 1'd0;
				else begin 
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6], pixel_index[5:0] + 1'd1};
				end
				if(data_valid) begin 
					data_temp <= idata;
				end
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];

			end 
			4'd6: begin
				if(down || left) data_valid <= 1'd0;
				else begin 
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6] + 1'd1, pixel_index[5:0] - 1'd1};
				end
				if(data_valid) begin 
					data_temp <= idata;
				end	
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];

			end 
			4'd7: begin
				if(down) data_valid <= 1'd0;
				else begin 
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6] + 1'd1, pixel_index[5:0]};
				end
				if(data_valid) begin 
					data_temp <= idata;
				end
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];

			end 
			4'd8: begin
				if(down || right) data_valid <= 1'd0;
				else begin 
					data_valid <= 1'd1;
					iaddr <= {pixel_index[11:6] + 1'd1, pixel_index[5:0] + 1'd1};
				end
				if(data_valid) begin 
					data_temp <= idata;
				end
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];

			end 
			4'd9: begin
				data_valid <= 1'd0;
				iaddr <= 12'd0;
				if(data_valid) begin 
					data_temp <= idata;
				end
				else data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index];

			end 
			4'd10: begin
				data_valid <= 1'd0;
				iaddr <= 12'd0;
				data_temp <= 20'd0;
				conv_result <= conv_result + data_temp * kernel[read_index] + bias; // conv result - bias
			end
			default: begin
				data_valid <= 1'd0;
				iaddr <= {pixel_index[11:6] - 1'd1, pixel_index[5:0] - 1'd1};
				data_temp <= 20'd0;
				conv_result <= conv_result;
			end
		endcase
	end
	else if(state == state_layer0) begin
		conv_result <= conv_result;
		data_valid <= 1'd0;
		iaddr <= {pixel_index[11:6] - 1'd1, pixel_index[5:0] - 1'd1};
		data_temp <= 20'd0;
	end
	else begin
		data_valid <= 1'd0;
		iaddr <= {pixel_index[11:6] - 1'd1, pixel_index[5:0] - 1'd1};
		data_temp <= 20'd0;
		conv_result <= 20'd0;
	end
end

reg signed [19:0] max_data;

// layer0 : write conv result and final result
always @(posedge clk or posedge reset) begin
	if (reset) begin
		caddr_wr <= 12'd0;
		cdata_wr <= 20'd0;
	end
	else if(state == state_layer0) begin
		caddr_wr <= pixel_index;
		if(!conv_result[39]) begin // 3/21 revised if(conv_result > 0) -> conv_result[39] == 1 ?
			if(conv_result[15]) cdata_wr <= {conv_result[35:16]} + 20'd1;
			else cdata_wr <= conv_result[35:16];
		end
		else cdata_wr <= 20'd0;
	end
	else if(state == state_write) begin
		caddr_wr <= write_index;
		cdata_wr <= max_data;
	end
end

// layer1


always @(posedge clk or posedge reset) begin
	if(reset) begin
		max_data <= 20'd0;
	end
	else if (state == state_layer1) begin
		case (maxpool_step)
			3'd0: caddr_rd <= pixel_index;
			3'd1: begin
				caddr_rd <= pixel_index + 12'd1;
				max_data <= cdata_rd;
			end
			3'd2: begin
				caddr_rd <= pixel_index + 12'd64;
				max_data <= (cdata_rd > max_data)? cdata_rd : max_data;
			end
			3'd3: begin
				caddr_rd <= pixel_index + 12'd65 ;
				max_data <= (cdata_rd > max_data)? cdata_rd : max_data; 
			end
			3'd4: begin
				caddr_rd <= pixel_index;
				max_data <= (cdata_rd > max_data)? cdata_rd : max_data; 
			end
			default: begin
				caddr_rd <= caddr_rd;
				max_data <= max_data;
			end
		endcase
	end
end


endmodule