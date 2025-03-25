`timescale 1ns/10ps
module GPSDC(clk, reset_n, DEN, LON_IN, LAT_IN, COS_ADDR, COS_DATA, ASIN_ADDR, ASIN_DATA, Valid, a, D);
input              clk;
input              reset_n;
input              DEN;
input      [23:0]  LON_IN;
input      [23:0]  LAT_IN;
input      [95:0]  COS_DATA;
output     [6:0]   COS_ADDR;
input      [127:0] ASIN_DATA;
output     [5:0]   ASIN_ADDR;
output             Valid;
output     [39:0]  D;
output     [63:0]  a;


// parameter
localparam S_IDLE   = 0;
localparam S_WAIT   = 1;
localparam S_FIND_A = 2;
localparam S_FIND_B = 3;
localparam S_INPUT  = 4;
localparam S_FIND_D = 5;
localparam S_CAL_D  = 6;
localparam S_DONE   = 7;

localparam rad = 16'h477; // 16 bits decimal
localparam R = 24'd12756274;

// declaration
reg [3:0] state_r, state_w;
reg [8:0] input_cnt_r, input_cnt_w;
reg [23:0] phi_A_r, phi_A_w, phi_B_r, phi_B_w, lambda_A_r, lambda_A_w ,lambda_B_r, lambda_B_w;
reg [6:0] cos_addr_r, cos_addr_w;
reg [5:0] asin_addr_r, asin_addr_w;
reg [95:0] COS_A_r, COS_A_w, COS_B_r, COS_B_w;
reg [95:0] cos_buffer;
wire [191:0] cos_interpolation_a, cos_interpolation_b;
reg [63:0] asin_r, asin_w;
reg [127:0] asin_buffer;
wire [150:0] asin_interpolation;
wire [300:0] temp1, temp2, a_temp;
wire [87:0] D_temp;

// assignment
assign COS_ADDR = cos_addr_r;
assign ASIN_ADDR = asin_addr_r;
// assign cos_interpolation_a = (cos_buffer[33:0] * (COS_DATA[89:48] - cos_buffer[89:48]) + ({phi_A_r, 16'd0} - cos_buffer[89:48]) * (COS_DATA[33:0] - cos_buffer[33:0]))/
//                            (COS_DATA[89:48] - cos_buffer[89:48]); // (8 + 72) / (8 + 32)

// assign cos_interpolation_b = (cos_buffer[33:0] * (COS_DATA[89:48] - cos_buffer[89:48]) + ({phi_B_r, 16'd0} - cos_buffer[89:48]) * (COS_DATA[33:0] - cos_buffer[33:0]))/
//                            (COS_DATA[89:48] - cos_buffer[89:48]); // (8 + 72) / (8 + 32)

assign cos_interpolation_a = ((cos_buffer[47:0] * (COS_DATA[95:48] - cos_buffer[95:48]) + ({8'd0, phi_A_r, 16'd0} - cos_buffer[95:48]) * (COS_DATA[47:0] - cos_buffer[47:0])) << 32)/
                           (COS_DATA[95:48] - cos_buffer[95:48]);

assign cos_interpolation_b = ((cos_buffer[47:0] * (COS_DATA[95:48] - cos_buffer[95:48]) + ({8'd0, phi_B_r, 16'd0} - cos_buffer[95:48]) * (COS_DATA[47:0] - cos_buffer[47:0])) << 32)/
                           (COS_DATA[95:48] - cos_buffer[95:48]);

assign temp1 = (((phi_B_r - phi_A_r) * rad) >> 1) * (((phi_B_r - phi_A_r) * rad) >> 1);
assign temp2 =  (COS_A_r * COS_B_r * (((lambda_B_r - lambda_A_r) * rad) >> 1) * (((lambda_B_r - lambda_A_r) * rad) >> 1));
//assign a_temp = {temp1[63:0], 128'd0} + {temp2};
assign a = temp1[63:0] + temp2[191:128];
//assign a = a_temp[191:128];
// assign asin_interpolation = (asin_buffer[47:0] * (ASIN_DATA[95:64] - asin_buffer[95:64]) + (a - asin_buffer[95:64]) * (ASIN_DATA[47:0] - asin_buffer[47:0]))/
//                            (ASIN_DATA[95:64] - asin_buffer[95:64]); // (0 + 80) / (0 + 32)

assign asin_interpolation = (asin_buffer[63:0] * (ASIN_DATA[127:64] - asin_buffer[127:64]) + (a - asin_buffer[127:64]) * (ASIN_DATA[63:0] - asin_buffer[63:0]))/
                           (ASIN_DATA[127:64] - asin_buffer[127:64]);

assign D_temp = R * asin_r;
assign D = D_temp[71:32];
assign Valid = state_r == S_DONE;

// FSM
always @(*) begin
    state_w = state_r;
    phi_A_w = phi_A_r;
    phi_B_w = phi_B_r;
    lambda_A_w = lambda_A_r;
    lambda_B_w = lambda_B_r;
    cos_addr_w  = cos_addr_r;
    asin_addr_w = asin_addr_r;
    COS_A_w     = COS_A_r;
    COS_B_w     = COS_B_r;
    asin_w      = asin_r;
    case (state_r)
        S_IDLE: begin
            if(DEN) begin
                state_w = S_WAIT;
                phi_A_w = LAT_IN;
                lambda_A_w = LON_IN;
            end
        end  
        S_WAIT: begin
            if(input_cnt_r == 9'd256) state_w = S_FIND_A;
        end
        S_FIND_A: begin
            cos_addr_w = cos_addr_r + 1;
            if(DEN) begin
                phi_B_w = LAT_IN;
                lambda_B_w = LON_IN;
            end
            else if({phi_A_r, 16'd0} <= COS_DATA[87:48]) begin
                state_w = S_FIND_B;
                cos_addr_w = 7'd0;
                COS_A_w = cos_interpolation_a[95:0];
            end
        end
        S_FIND_B: begin
            cos_addr_w = cos_addr_r + 1;
            if({phi_B_r, 16'd0} <= COS_DATA[87:48]) begin
                state_w = S_FIND_D;
                cos_addr_w = 7'd0;
                COS_B_w = cos_interpolation_b[95:0];
            end
        end
        S_FIND_D: begin
            asin_addr_w = asin_addr_r + 1;
            if(a == 64'd0) begin
                state_w = S_DONE;
                asin_addr_w = 7'd0;
                asin_w = 64'd0;
            end
            else if(a <= ASIN_DATA[127:64]) begin
                state_w = S_DONE;
                asin_addr_w = 7'd0;
                asin_w = asin_interpolation[63:0];
            end
        end
        S_DONE: begin
            state_w = S_INPUT;
            input_cnt_w = 9'd0;
            phi_A_w     = phi_B_r;
            phi_B_w     = 24'd0;
            lambda_A_w  = lambda_B_w;
            lambda_B_w  = 24'd0;
            cos_addr_w  = 7'd0;
            asin_addr_w = 6'd0;
            COS_A_w     = COS_B_w;
            COS_B_w     = 48'd0;
            asin_w      = 64'd0;
        end
        S_INPUT: begin
            if(DEN) begin
                state_w = S_FIND_B;
                phi_B_w = LAT_IN;
                lambda_B_w = LON_IN;
            end
        end
    endcase
end

// input counter
always @(*) begin
    input_cnt_w = input_cnt_r;
    case (state_r)
        S_WAIT: begin
            if(input_cnt_r == 9'd256) input_cnt_w = 9'd0;
            else input_cnt_w = input_cnt_r + 1;
        end  
    endcase
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        state_r <= S_IDLE;
        input_cnt_r <= 9'd0;
        phi_A_r     <= 24'd0;
        phi_B_r     <= 24'd0;
        lambda_A_r  <= 24'd0;
        lambda_B_r  <= 24'd0;
        cos_addr_r  <= 7'd0;
        asin_addr_r <= 6'd0;
        COS_A_r     <= 48'd0;
        COS_B_r     <= 48'd0;
        cos_buffer  <= 96'd0;
        asin_buffer <= 128'd0;
        asin_r      <= 64'd0;
    end
    else begin
        state_r <= state_w;
        input_cnt_r <= input_cnt_w;
        phi_A_r     <= phi_A_w;
        phi_B_r     <= phi_B_w;
        lambda_A_r  <= lambda_A_w;
        lambda_B_r  <= lambda_B_w;
        cos_addr_r  <= cos_addr_w;
        asin_addr_r <= asin_addr_w;
        COS_A_r     <= COS_A_w;
        COS_B_r     <= COS_B_w;
        cos_buffer  <= COS_DATA;
        asin_buffer <= ASIN_DATA;
        asin_r      <= asin_w;
    end
end

endmodule
