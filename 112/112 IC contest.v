module Bicubic (
input CLK,
input RST,
input [6:0] V0,
input [6:0] H0,
input [4:0] SW,
input [4:0] SH,
input [5:0] TW,
input [5:0] TH,
output reg DONE);








parameter state_ICR    = 4'd0;
parameter state_OFF00  = 4'd1;
parameter state_OFF10  = 4'd2;
parameter state_OFF01  = 4'd3;
parameter state_OFF11  = 4'd4;
parameter state_WB     = 4'd5;
parameter state_DONE   = 4'd6;
parameter state_IDLE   = 4'd7;
parameter state_CAL    = 4'd8;


//-------------reg/wire declaration-------------------
reg [3:0] state, nxt_state;
reg [7:0] data[3:0];
reg [6:0] ix, iy;
reg [6:0] jx, jy;
wire [1:0] check;
reg initial_flag;
wire signed [13:0] x_p, y_p;
wire signed [14:0] x_p_float, y_p_cal_float;
wire [14:0] A_X, A_Y;
wire [7:0] data_ROM;
wire signed [13:0] Addr_RAM;
reg [4:0] count;
wire [13:0] WB_A;
wire [7:0] WB_D;
reg WEN, CEN;
reg WB_flag;
wire [7:0] trash;
assign trash = 0;
wire signed [1:0] match_x, match_y;
reg [1:0] read_flag;
reg [1:0] row, col;
wire signed [2:0] bias_X [3:0][3:0];
wire signed [2:0] bias_Y [3:0][3:0];
reg [7:0] temp1, temp2, temp3, temp4;
reg signed [14:0] tempx;
reg [14:0] tempA;
wire [7:0] result;
wire wen;
wire WAIT;
wire signed [6:0] add_X, add_Y;
wire CEN_ROM;
//------------module------------------------------
ImgROM u_ImgROM (.Q(data_ROM), .CLK(CLK), .CEN(CEN_ROM), .A(Addr_RAM));
ResultSRAM u_ResultSRAM (.Q(trash), .CLK(CLK), .CEN(CEN), .WEN(tmp), .A(WB_A), .D(WB_D));
//-------------assignment-----------------------------
assign check = {match_x != 0, match_y != 0};
assign DONE = (state == state_DONE) ? 1 : 0;
assign CEN_ROM = (read_flag < 2) ? 0:1;
//-------------FSM------------------------------------
always @(*) begin
    case (state)
        state_ICR : begin
            case (check)
                2'b00: nxt_state = state_OFF00;
                2'b10: nxt_state = state_OFF10;
                2'b01: nxt_state = state_OFF01;
                2'b11: nxt_state = state_OFF11;
                default: nxt_state = state;
            endcase
        end
        state_OFF00: nxt_state = (count == 5'd16) ? state_WB : ((col == 2'd3 && read_flag == 2)? state_CAL: state_OFF00);
        state_OFF10: nxt_state = (count == 5'd3)? state_CAL: state_OFF10;
        state_OFF01: nxt_state = (count == 5'd3)? state_CAL: state_OFF01;
        state_OFF11: nxt_state = (count == 5'd0)? state_WB: state_OFF11;
        state_WB  : nxt_state = (WB_flag)? ((jx == TW - 1 && jy == TH - 1)? state_DONE : state_ICR ) : state_WB;
        state_CAL: nxt_state = (WAIT)? ((check == 2'b00)? ((count == 17) ? state_WB: state_OFF00) : state_WB): state_CAL;
        state_DONE: nxt_state = state_IDLE;
        state_IDLE: nxt_state = state_ICR;
        default: nxt_state = state;
    endcase
end
always @(posedge CLK or posedge RST) begin
    if(RST)begin
        state <= state_IDLE;
    end
    else begin
        state <= nxt_state;
    end
end
//-------------WB---------------------------------------
always @(posedge CLK) begin
    if(nxt_state == state_WB && state != state_WB)begin
        CEN <= 0;
        WEN <= 0;
        WB_flag <= 0;
    end
    else if (state == state_WB) begin
        CEN <= 0;
        WEN <= 0;
        WB_flag <= 1;
    end
    else if(nxt_state == state_ICR)begin
        CEN <= 1;
        WEN <= 0;
        WB_flag <= 0;
    end
    else begin
        CEN <= 1;
        WEN <= 0;
        WB_flag <= 0;
    end
end
assign WB_A = {jx,jy};
assign WB_D = result; // output of module cul


//---------------x, y control--------------------------


assign x_p = SW*jx - TW*ix;
assign y_p = SW*jy - TW*iy;
assign x_p_float = x_p << 1;
assign y_p_float = y_p << 1;
assign A_X = SW * TW <<1;
assign A_Y = SH * TH <<1;
assign match_x =    (x_p < 0) ? -2'd1:
                    (x_p ==  0) ? 0: 2'd1;
assign match_y =    (y_p < 0) ? -2'd1:
                    (y_p ==  0) ? 0: 2'd1;
//ix
always @(posedge CLK) begin
    if(state == state_IDLE) begin
        ix <= 0;
    end
    else if(state == state_ICR) begin
        if(ix + 1 < SW)begin
            if(match_x > 0) begin
                ix <= ix+ 1;
            end
            else ix <= ix;
        end
        else //歸零
            ix <= 0;
    end
    else begin
        ix <= ix;
    end
end
//iy
always @(posedge CLK) begin
    if(state == state_IDLE) begin
        iy <= 0;
    end
    else if(state == state_ICR) begin
        if(iy < SH)begin
            if(ix == SW - 1) begin
                if(match_y >= 0)
                    iy <= iy+ 1;
                else
                    iy <= iy;
            end
            else
                iy <= iy;
        end
        else //歸零
            iy <= 0;
        end
    else begin
        iy <= iy;
    end
end
//jx
always @(posedge CLK) begin
    if(state == state_IDLE) begin
        jx <= 0;
        initial_flag <= 0;
    end
    else if(state == state_ICR) begin
        if(jx +1 < TH)begin
            jx <= (initial_flag)?  jx + 1 : jx;
            initial_flag <= 1;
        end
        else //歸零
            jx <= 0;
    end
    else begin
        jx <= jx;
    end
end
//jy
always @(posedge CLK) begin
    if(state == state_IDLE) begin
        jy <= 0;
    end
    else if(state == state_ICR) begin
        if(jy < TH)begin
            if(jx == TW - 1) begin
                jy <= jy+ 1;
            end
            else
                jy <= jy;
        end
        else //歸零
            jy <= 0;
        end
    else begin
        jy <= jy;
    end
end
//----------------Read--------------------------
assign bias_X[0][0] = -3'd2; assign bias_X[0][1] = -3'd1; assign bias_X[0][2] =  3'd0; assign bias_X[0][3] =  3'd1;
assign bias_X[1][0] = -3'd2; assign bias_X[1][1] = -3'd1; assign bias_X[1][2] =  3'd0; assign bias_X[1][3] =  3'd1;
assign bias_X[2][0] = -3'd2; assign bias_X[2][1] = -3'd1; assign bias_X[2][2] =  3'd0; assign bias_X[2][3] =  3'd1;
assign bias_X[3][0] = -3'd2; assign bias_X[3][1] = -3'd1; assign bias_X[3][2] =  3'd0; assign bias_X[3][3] =  3'd1;
assign bias_Y[0][0] = -3'd2; assign bias_Y[0][1] = -3'd2; assign bias_Y[0][2] = -3'd2; assign bias_Y[0][3] = -3'd2;
assign bias_Y[1][0] = -3'd1; assign bias_Y[1][1] = -3'd1; assign bias_Y[1][2] = -3'd1; assign bias_Y[1][3] = -3'd1;
assign bias_Y[2][0] =  3'd0; assign bias_Y[2][1] =  3'd0; assign bias_Y[2][2] =  3'd0; assign bias_Y[2][3] =  3'd0;
assign bias_Y[3][0] =  3'd1; assign bias_Y[3][1] =  3'd1; assign bias_Y[3][2] =  3'd1; assign bias_Y[3][3] =  3'd1;
assign add_X = SW + jx + bias_X[row][col];
assign add_Y = SH + jy + bias_Y[row][col];


//-------------------row, col------------------------------
always @(posedge CLK or posedge RST) begin
    if(RST || state == state_ICR) begin
        row <= 0;
        col <= 0;
    end
    else begin
        case (state)
            state_OFF00: begin
                if(read_flag == 2) begin
                    col <= (col < 3)? col + 1 : 0;
                    row <= (row < 3)? ((col == 3) ? row + 1 : row) :
                            (row == 3)? row: 0;
                end
            end
            state_OFF10: begin //x match; y unmatch
                if(read_flag == 2) begin
                    col <= 2;
                    row <= (row < 3)?  row + 1 : 0;
                end
            end
            state_OFF01: begin //y match; x unmatch
                if(read_flag == 2) begin
                    col <= (col < 3)? col + 1 : 0;
                    row <= 2;
                end
            end
            state_OFF11: begin //y match; y unmatch
                if(read_flag == 2) begin
                    col <= 2;
                    row <= 2;
                end
            end
            default: begin
                row <= row;
                col <= col;
            end
        endcase
    end
end
integer i;
//---------------Read--------------------------
assign Addr_RAM =  {add_Y, add_X};
always @(posedge CLK or posedge RST) begin
    if(RST || state == state_ICR) begin
        read_flag <= 0;
        for (i = 0; i < 3; i = i + 1) begin
            data[i] <= 0;
        end
        count <= 0;
    end
    else if(state == state_OFF00 || state == state_OFF01 || state == state_OFF10 || state == state_OFF11) begin
        if(read_flag == 0) begin
            read_flag <= 1;
            count <= count;
        end
        else if(read_flag == 1) begin
            data[row] <= data_ROM;
            read_flag <= 2;
            count <= count;
        end
        else if(read_flag == 2) begin
            read_flag <= 0;
            count <= count + 1;
        end
    end
    else begin
        for (i = 0; i < 3; i = i + 1) begin
            data[i] <= data[i];
        end
        read_flag <= 0;
        count <= count;
    end
end
//------------Cal parameter-------------------------------


assign wen = (state == state_CAL)? 1:0;
CAL a0( .CLK(CLK),
        .WEN(wen),
        .data1(temp1),
        .data2(temp2),
        .data3(temp3),
        .data4(temp4),
        .x(tempx),
        .A(tempA),
        .OUTPUT(result),
        .WAIT(WAIT));


reg [7:0] tmp_result [0:3];
reg cal_XY; //=0 cal_x; =1 cal_Y
always @(posedge CLK) begin
    case (state)
        state_OFF00: begin
            cal_XY <= (count == 15) ?1 :0;
        end
        state_OFF10: begin
            cal_XY <= 1;
        end
        state_OFF01: begin
            cal_XY <= 0;
        end
        default: begin
            cal_XY <= 0;
        end
    endcase
end
always @(posedge CLK or posedge RST) begin
    if(RST || state == state_ICR) begin
        temp1 <= 0;
        temp2 <= 0;
        temp3 <= 0;
        temp4 <= 0;
        tempx <= 0;
        tempA <= 0;
        for (i = 0; i < 3; i = i + 1) begin
            tmp_result[i] <= 0;
        end
    end
    else if(state == state_CAL)begin
        temp1 <= (count > 15)? tmp_result[0] : data[0];
        temp2 <= (count > 15)? tmp_result[1] : data[1];
        temp3 <= (count > 15)? tmp_result[2] : data[2];
        temp4 <= (count > 15)? tmp_result[3] : data[3];
        tempx <= (cal_XY) ? y_p_float : x_p_float;
        tempA <= (cal_XY) ? A_Y: A_X;
        if(~WAIT) tmp_result[col] <= result;
    end
    else begin
        temp1 <= temp1;
        temp2 <= temp2;
        temp3 <= temp3;
        temp4 <= temp4;
        tempx <= tempx;
        tempA <= tempA;
        for (i = 0; i < 3; i = i + 1) begin
            tmp_result[i] <= tmp_result[i];
        end
    end
end
endmodule


module CAL (
    input CLK,
    input WEN,
    input   [7:0] data1,
    input   [7:0] data2,
    input   [7:0] data3,
    input   [7:0] data4,
    input   signed [14:0] x,
    input   [14:0] A,
    output  reg [7:0] OUTPUT,
    output  reg WAIT);




wire signed[11:0] a,b,c,d; // abcd are 11 bits integer + 1 bit point
assign a =  (((data2<<2)+(data2<<1))>>2) - (data1) - (((data3<<2)+data3)>>1) + (data4);
assign b =  data1 - (((data2<<3)+(data2<<1))>>2) + (data3<<2) - (data4);
assign c =  (data3) - (data1);
assign d =  data2<<1;




wire signed [57:0] final_result;
reg signed [57:0] temp_result;
reg cal;
reg [2:0] result_counter;




always @(posedge CLK) begin
    if(!WEN)begin
        cal <= 0;
        result_counter <= 0;
        WAIT <= 0;
    end
    if(WEN) begin
        case (result_counter)
            0:begin
                temp_result <= a * x *  x * x;
                result_counter <= result_counter + 1;
            end
            1:begin
                temp_result <= b * x *  x * A + temp_result;
                result_counter <= result_counter + 1;
            end
            2:begin
                temp_result <= c * x *  A * A + temp_result;
                result_counter <= result_counter + 1;
            end
            3:begin
                temp_result <= d * A *  A * A + temp_result;
                result_counter <= result_counter + 1;
            end
            4:begin
                if(final_result[57]) OUTPUT <= 0;
                else if(final_result > 58'd510) OUTPUT <= 8'd255;
                else OUTPUT <= (final_result[0])? final_result[8:1] + 1 : final_result[8:1];
                result_counter <= 0;
                cal <= 0;
                WAIT <= 1;
            end
            default: result_counter <= result_counter;
        endcase
    end
end




assign final_result = (temp_result / (A*A*A));




endmodule







