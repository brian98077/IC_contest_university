module CONVEX(
input CLK,
input RST,
input [4:0] PT_XY,
output reg READ_PT,
output reg [9:0] DROP_X,
output reg [9:0] DROP_Y,
output reg DROP_V);

// state
parameter S_IDLE       = 0;
parameter S_INPUT      = 1;
parameter S_CHECK      = 2;
parameter S_SAME_POINT = 3;
parameter S_FIND       = 4;
parameter S_POP        = 5;
parameter S_SAME_LINE  = 6;
parameter S_STOP       = 7;
parameter S_ADD_LAST   = 8;

// declaration
reg [3:0] state_w, state_r;
reg [4:0] max_index_w, max_index_r, curr_index_w, curr_index_r; // start from index 1 to 12, index 0 is useless
reg [129:0] data_X_w, data_X_r, data_Y_w, data_Y_r; // start from 10 ~ 19 to 120 ~ 129, 0 ~ 9 bit are empty
reg READ_PT_w, DROP_V_w;
reg [2:0] input_cnt_w, input_cnt_r;
reg [9:0] Xn_r, Yn_r, Xn_w, Yn_w;
reg [9:0] DROP_X_w, DROP_Y_w;
reg find_con_valid_r, find_con_valid_w;
wire find_cov_finish, stop, pop, same;
wire [1:0] pop_index, same_index, stop_index;

wire [7:0] curr_idx_20 = 10*curr_index_r+20;
wire [7:0] curr_idx_10 = 10*curr_index_r+10;
wire [7:0] curr_idx_19 = 10*curr_index_r+19;

wire [9:0] data_x [0:12];
wire [9:0] data_y [0:12];


wire [9:0] x1_input, x2_input, x3_input, y1_input, y2_input, y3_input;
assign x1_input = (curr_index_r >  max_index_r)? data_X_r[10*(curr_index_r - max_index_r) +:10]: data_X_r[10*curr_index_r +:10];

assign x2_input = (curr_index_r == max_index_r || curr_index_r == 2*max_index_r)? data_X_r[10 +:10]: 
                    (curr_index_r > max_index_r)? data_X_r[10*(curr_index_r - max_index_r)+10 +:10]: data_X_r[10*(curr_index_r)+10 +:10];

assign x3_input = (curr_index_r == max_index_r-1 || curr_index_r == 2*max_index_r-1)? data_X_r[10 +:10]:
                (curr_index_r == max_index_r || curr_index_r == 2*max_index_r)? data_X_r[20 +:10]: 
                (curr_index_r > max_index_r)? data_X_r[10*(curr_index_r - max_index_r)+20 +:10]: data_X_r[10*(curr_index_r)+20 +:10];

assign y1_input = (curr_index_r >  max_index_r)? data_Y_r[10*(curr_index_r - max_index_r) +:10]: data_Y_r[10*curr_index_r +:10];

assign y2_input = (curr_index_r == max_index_r || curr_index_r == 2*max_index_r)? data_Y_r[10 +:10]: 
                 (curr_index_r > max_index_r)? data_Y_r[10*(curr_index_r - max_index_r)+10 +:10]: data_Y_r[10*(curr_index_r )+10 +:10];

assign y3_input = (curr_index_r == max_index_r-1 || curr_index_r == 2*max_index_r-1)? data_Y_r[10 +:10]:
                (curr_index_r == max_index_r || curr_index_r == 2*max_index_r)? data_Y_r[20 +:10]: 
                (curr_index_r > max_index_r)? data_Y_r[10*(curr_index_r - max_index_r)+20 +:10]: data_Y_r[10*(curr_index_r)+20 +:10];


genvar i;
generate
    for (i = 0; i<12;i=i+1 ) begin: x
        assign data_x[i] = data_X_r[10*i+:10];
        assign data_y[i] = data_Y_r[10*i+:10];
    end
endgenerate

// find convex module
find_convex FIND_CON(
    .CLK(CLK),
    .RST(RST),
    .i_valid(find_con_valid_r),
    .X1(x1_input),
    .Y1(y1_input),
    .X2(x2_input),
    .Y2(y2_input),
    .X3(x3_input),
    .Y3(y3_input),
    .Xn(Xn_r),
    .Yn(Yn_r),
    .o_valid(find_cov_finish),
    .stop(stop),
    .pop(pop),
    .same(same),
    .pop_index(pop_index),
    .same_index(same_index),
    .stop_index(stop_index)
);

// FSM
always @(*) begin
    state_w = state_r;
    READ_PT_w = READ_PT;
    Xn_w = Xn_r;
    Yn_w = Yn_r;
    max_index_w = max_index_r;
    curr_index_w = curr_index_r;
    DROP_V_w = 0;
    DROP_X_w = 10'd0;
    DROP_Y_w = 10'd0;
    data_X_w = data_X_r;
    data_Y_w = data_Y_r;
    find_con_valid_w = find_con_valid_r;
    case (state_r)
        S_IDLE: begin
            state_w = S_INPUT;
            READ_PT_w = 1;
            curr_index_w = 5'd1;
            find_con_valid_w = 0;
        end
        S_INPUT: begin
            case (input_cnt_r)
                0: begin
                    READ_PT_w = 0;
                    state_w = S_INPUT;
                end 
                1: begin
                    Xn_w[9:5] = PT_XY;
                    state_w = S_INPUT;
                end
                2: begin
                    Xn_w[4:0] = PT_XY;
                    state_w = S_INPUT;
                end
                3: begin
                    Yn_w[9:5] = PT_XY;
                    state_w = S_INPUT;
                end
                4: begin
                    Yn_w[4:0] = PT_XY;
                    state_w = S_CHECK;
                end
            endcase
        end
        S_CHECK: begin // check number of data >= 3
            if(max_index_r < 4'd3) begin
                state_w = S_IDLE;
                max_index_w = max_index_r + 1;
                data_X_w[10*max_index_w +:10] = Xn_r;
                data_Y_w[10*max_index_w +:10] = Yn_r;
            end
            else begin
                state_w = S_SAME_POINT;
            end
        end
        S_SAME_POINT: begin
            if(data_X_r[10*curr_index_r +:10] == Xn_r && data_Y_r[10*curr_index_r +:10] == Yn_r && curr_index_r < max_index_r) begin
                DROP_V_w = 1;
                DROP_X_w = Xn_r;
                DROP_Y_w = Yn_r;
                state_w = S_IDLE;
                curr_index_w = 5'd1;
            end
            else if(curr_index_r == max_index_r * 2) begin
                state_w = S_FIND;
                curr_index_w = 5'd1;
                find_con_valid_w = 1;
            end
            else begin
                curr_index_w = curr_index_r + 1;
                state_w = S_SAME_POINT;
            end
        end
        S_FIND: begin
            find_con_valid_w = 0;
            if(find_cov_finish && stop && curr_index_r > max_index_r) begin
                state_w = S_STOP;
            end
            else if(find_cov_finish && pop) begin
                state_w = S_POP;
            end
            else if(find_cov_finish && same) begin
                state_w = S_SAME_LINE;
            end
            else if(find_cov_finish && curr_index_r == 2*max_index_r) begin // iteration over
                DROP_V_w = 1;
                DROP_X_w = Xn_w;
                DROP_Y_w = Yn_w;
                state_w = S_IDLE;
            end
            else if(find_cov_finish) begin
                find_con_valid_w = 1;
                curr_index_w = curr_index_r + 1;
                state_w = S_FIND;
            end
            else begin
                state_w = S_FIND; // wait find convex module
            end
        end
        S_STOP: begin
            max_index_w = max_index_r + 1;
            data_X_w[10*(curr_index_r-max_index_r)+10 +:10] = Xn_r;
            data_Y_w[10*(curr_index_r-max_index_r)+10 +:10] = Yn_r;
            state_w = S_IDLE;
            curr_index_w = 5'd1;
            // data_X_w[129: 10*curr_index_r+20] = data_X_r[119: 10*curr_index_r+10];
            // data_Y_w[129: 10*curr_index_r+20] = data_Y_r[119: 10*curr_index_r+10];
            case (curr_index_r-max_index_r)
                1: begin
                    data_X_w[129: 10*1+20] = data_X_r[119: 10*1+10];
                    data_Y_w[129: 10*1+20] = data_Y_r[119: 10*1+10];
                end
                2: begin
                    data_X_w[129: 10*2+20] = data_X_r[119: 10*2+10];
                    data_Y_w[129: 10*2+20] = data_Y_r[119: 10*2+10];
                end
                3: begin
                    data_X_w[129: 10*3+20] = data_X_r[119: 10*3+10];
                    data_Y_w[129: 10*3+20] = data_Y_r[119: 10*3+10];
                end
                4: begin
                    data_X_w[129: 10*4+20] = data_X_r[119: 10*4+10];
                    data_Y_w[129: 10*4+20] = data_Y_r[119: 10*4+10];
                end
                5: begin
                    data_X_w[129: 10*5+20] = data_X_r[119: 10*5+10];
                    data_Y_w[129: 10*5+20] = data_Y_r[119: 10*5+10];
                end
                6: begin
                    data_X_w[129: 10*6+20] = data_X_r[119: 10*6+10];
                    data_Y_w[129: 10*6+20] = data_Y_r[119: 10*6+10];
                end
                7: begin
                    data_X_w[129: 10*7+20] = data_X_r[119: 10*7+10];
                    data_Y_w[129: 10*7+20] = data_Y_r[119: 10*7+10];
                end
                8: begin
                    data_X_w[129: 10*8+20] = data_X_r[119: 10*8+10];
                    data_Y_w[129: 10*8+20] = data_Y_r[119: 10*8+10];
                end
                9: begin
                    data_X_w[129: 10*9+20] = data_X_r[119: 10*9+10];
                    data_Y_w[129: 10*9+20] = data_Y_r[119: 10*9+10];
                end
                10: begin
                    data_X_w[129: 10*10+20] = data_X_r[119: 10*10+10];
                    data_Y_w[129: 10*10+20] = data_Y_r[119: 10*10+10];
                end
                default: begin
                    data_X_w = data_X_r;
                    data_Y_w = data_Y_r;
                end
            endcase
        end
        S_POP: begin
            max_index_w = max_index_r - 1;
            DROP_V_w = 1;
            DROP_X_w = (curr_index_r + pop_index > max_index_r) ? data_X_r[10*(curr_index_r + pop_index - max_index_r) +:10] : data_X_r[10*(curr_index_r + pop_index) +:10];
            DROP_Y_w = (curr_index_r + pop_index > max_index_r) ? data_Y_r[10*(curr_index_r + pop_index - max_index_r) +:10] : data_Y_r[10*(curr_index_r + pop_index) +:10];
            state_w = (curr_index_r == 2*max_index_r || max_index_r == 3) ? S_ADD_LAST : S_FIND;
            find_con_valid_w = 1;
            // data_X_w[129: 10*(curr_index_r + pop_index)] = {10'd0, data_X_r[129: 10*(curr_index_r + pop_index)+10]};
            // data_Y_w[129: 10*(curr_index_r + pop_index)] = {10'd0, data_Y_r[129: 10*(curr_index_r + pop_index)+10]};
            if(curr_index_r + pop_index > max_index_r) begin
                case (curr_index_r + pop_index - max_index_r)
                1: begin
                    data_X_w[129: 10*1] = {10'd0, data_X_r[129: 10*1+10]};
                    data_Y_w[129: 10*1] = {10'd0, data_Y_w[129: 10*1+10]};
                end
                2: begin
                    data_X_w[129: 10*2] = {10'd0, data_X_r[129: 10*2+10]};
                    data_Y_w[129: 10*2] = {10'd0, data_Y_w[129: 10*2+10]};
                end
                3: begin
                    data_X_w[129: 10*3] = {10'd0, data_X_r[129: 10*3+10]};
                    data_Y_w[129: 10*3] = {10'd0, data_Y_w[129: 10*3+10]};
                end
                4: begin
                    data_X_w[129: 10*4] = {10'd0, data_X_r[129: 10*4+10]};
                    data_Y_w[129: 10*4] = {10'd0, data_Y_w[129: 10*4+10]};
                end
                5: begin
                    data_X_w[129: 10*5] = {10'd0, data_X_r[129: 10*5+10]};
                    data_Y_w[129: 10*5] = {10'd0, data_Y_w[129: 10*5+10]};
                end
                6: begin
                    data_X_w[129: 10*6] = {10'd0, data_X_r[129: 10*6+10]};
                    data_Y_w[129: 10*6] = {10'd0, data_Y_w[129: 10*6+10]};
                end
                7: begin
                    data_X_w[129: 10*7] = {10'd0, data_X_r[129: 10*7+10]};
                    data_Y_w[129: 10*7] = {10'd0, data_Y_w[129: 10*7+10]};
                end
                8: begin
                    data_X_w[129: 10*8] = {10'd0, data_X_r[129: 10*8+10]};
                    data_Y_w[129: 10*8] = {10'd0, data_Y_w[129: 10*8+10]};
                end
                9: begin
                    data_X_w[129: 10*9] = {10'd0, data_X_r[129: 10*9+10]};
                    data_Y_w[129: 10*9] = {10'd0, data_Y_w[129: 10*9+10]};
                end
                10: begin
                    data_X_w[129: 10*10] = {10'd0, data_X_r[129: 10*10+10]};
                    data_Y_w[129: 10*10] = {10'd0, data_Y_w[129: 10*10+10]};
                end
                default: begin
                    data_X_w = data_X_r;
                    data_Y_w = data_Y_r;
                end
            endcase
            end
            else begin
                case (curr_index_r + pop_index)
                1: begin
                    data_X_w[129: 10*1] = {10'd0, data_X_r[129: 10*1+10]};
                    data_Y_w[129: 10*1] = {10'd0, data_Y_w[129: 10*1+10]};
                end
                2: begin
                    data_X_w[129: 10*2] = {10'd0, data_X_r[129: 10*2+10]};
                    data_Y_w[129: 10*2] = {10'd0, data_Y_w[129: 10*2+10]};
                end
                3: begin
                    data_X_w[129: 10*3] = {10'd0, data_X_r[129: 10*3+10]};
                    data_Y_w[129: 10*3] = {10'd0, data_Y_w[129: 10*3+10]};
                end
                4: begin
                    data_X_w[129: 10*4] = {10'd0, data_X_r[129: 10*4+10]};
                    data_Y_w[129: 10*4] = {10'd0, data_Y_w[129: 10*4+10]};
                end
                5: begin
                    data_X_w[129: 10*5] = {10'd0, data_X_r[129: 10*5+10]};
                    data_Y_w[129: 10*5] = {10'd0, data_Y_w[129: 10*5+10]};
                end
                6: begin
                    data_X_w[129: 10*6] = {10'd0, data_X_r[129: 10*6+10]};
                    data_Y_w[129: 10*6] = {10'd0, data_Y_w[129: 10*6+10]};
                end
                7: begin
                    data_X_w[129: 10*7] = {10'd0, data_X_r[129: 10*7+10]};
                    data_Y_w[129: 10*7] = {10'd0, data_Y_w[129: 10*7+10]};
                end
                8: begin
                    data_X_w[129: 10*8] = {10'd0, data_X_r[129: 10*8+10]};
                    data_Y_w[129: 10*8] = {10'd0, data_Y_w[129: 10*8+10]};
                end
                9: begin
                    data_X_w[129: 10*9] = {10'd0, data_X_r[129: 10*9+10]};
                    data_Y_w[129: 10*9] = {10'd0, data_Y_w[129: 10*9+10]};
                end
                10: begin
                    data_X_w[129: 10*10] = {10'd0, data_X_r[129: 10*10+10]};
                    data_Y_w[129: 10*10] = {10'd0, data_Y_w[129: 10*10+10]};
                end
                default: begin
                    data_X_w = data_X_r;
                    data_Y_w = data_Y_r;
                end
            endcase
            end
        end
        S_SAME_LINE: begin
            DROP_V_w = 1;
            if(same_index == 3) begin
                DROP_X_w = Xn_r;
                DROP_Y_w = Yn_r;
                state_w = S_IDLE;
            end
            else begin
                state_w = S_FIND;
                find_con_valid_w = 1;
                max_index_w = max_index_r - 1;
                DROP_X_w = (curr_index_r + same_index > max_index_r) ? data_X_r[10*(curr_index_r + same_index - max_index_r) +:10] : data_X_r[10*(curr_index_r + same_index) +:10];
                DROP_Y_w = (curr_index_r + same_index > max_index_r) ? data_Y_r[10*(curr_index_r + same_index - max_index_r) +:10] : data_Y_r[10*(curr_index_r + same_index) +:10];
                // data_X_w[129: 10*(curr_index_r + same_index)] = {10'd0, data_X_r[129: 10*(curr_index_r + same_index)+10]};
                // data_Y_w[129: 10*(curr_index_r + same_index)] = {10'd0, data_Y_r[129: 10*(curr_index_r + same_index)+10]};
                if(curr_index_r + same_index > max_index_r) begin
                    case (curr_index_r + same_index - max_index_r)
                        1: begin
                            data_X_w[129: 10*1] = {10'd0, data_X_r[129: 10*1+10]};
                            data_Y_w[129: 10*1] = {10'd0, data_Y_w[129: 10*1+10]};
                        end
                        2: begin
                            data_X_w[129: 10*2] = {10'd0, data_X_r[129: 10*2+10]};
                            data_Y_w[129: 10*2] = {10'd0, data_Y_w[129: 10*2+10]};
                        end
                        3: begin
                            data_X_w[129: 10*3] = {10'd0, data_X_r[129: 10*3+10]};
                            data_Y_w[129: 10*3] = {10'd0, data_Y_w[129: 10*3+10]};
                        end
                        4: begin
                            data_X_w[129: 10*4] = {10'd0, data_X_r[129: 10*4+10]};
                            data_Y_w[129: 10*4] = {10'd0, data_Y_w[129: 10*4+10]};
                        end
                        5: begin
                            data_X_w[129: 10*5] = {10'd0, data_X_r[129: 10*5+10]};
                            data_Y_w[129: 10*5] = {10'd0, data_Y_w[129: 10*5+10]};
                        end
                        6: begin
                            data_X_w[129: 10*6] = {10'd0, data_X_r[129: 10*6+10]};
                            data_Y_w[129: 10*6] = {10'd0, data_Y_w[129: 10*6+10]};
                        end
                        7: begin
                            data_X_w[129: 10*7] = {10'd0, data_X_r[129: 10*7+10]};
                            data_Y_w[129: 10*7] = {10'd0, data_Y_w[129: 10*7+10]};
                        end
                        8: begin
                            data_X_w[129: 10*8] = {10'd0, data_X_r[129: 10*8+10]};
                            data_Y_w[129: 10*8] = {10'd0, data_Y_w[129: 10*8+10]};
                        end
                        9: begin
                            data_X_w[129: 10*9] = {10'd0, data_X_r[129: 10*9+10]};
                            data_Y_w[129: 10*9] = {10'd0, data_Y_w[129: 10*9+10]};
                        end
                        10: begin
                            data_X_w[129: 10*10] = {10'd0, data_X_r[129: 10*10+10]};
                            data_Y_w[129: 10*10] = {10'd0, data_Y_w[129: 10*10+10]};
                        end
                        default: begin
                            data_X_w = data_X_r;
                            data_Y_w = data_Y_r;
                        end
                    endcase
                end
                else begin
                    case (curr_index_r + same_index)
                        1: begin
                            data_X_w[129: 10*1] = {10'd0, data_X_r[129: 10*1+10]};
                            data_Y_w[129: 10*1] = {10'd0, data_Y_w[129: 10*1+10]};
                        end
                        2: begin
                            data_X_w[129: 10*2] = {10'd0, data_X_r[129: 10*2+10]};
                            data_Y_w[129: 10*2] = {10'd0, data_Y_w[129: 10*2+10]};
                        end
                        3: begin
                            data_X_w[129: 10*3] = {10'd0, data_X_r[129: 10*3+10]};
                            data_Y_w[129: 10*3] = {10'd0, data_Y_w[129: 10*3+10]};
                        end
                        4: begin
                            data_X_w[129: 10*4] = {10'd0, data_X_r[129: 10*4+10]};
                            data_Y_w[129: 10*4] = {10'd0, data_Y_w[129: 10*4+10]};
                        end
                        5: begin
                            data_X_w[129: 10*5] = {10'd0, data_X_r[129: 10*5+10]};
                            data_Y_w[129: 10*5] = {10'd0, data_Y_w[129: 10*5+10]};
                        end
                        6: begin
                            data_X_w[129: 10*6] = {10'd0, data_X_r[129: 10*6+10]};
                            data_Y_w[129: 10*6] = {10'd0, data_Y_w[129: 10*6+10]};
                        end
                        7: begin
                            data_X_w[129: 10*7] = {10'd0, data_X_r[129: 10*7+10]};
                            data_Y_w[129: 10*7] = {10'd0, data_Y_w[129: 10*7+10]};
                        end
                        8: begin
                            data_X_w[129: 10*8] = {10'd0, data_X_r[129: 10*8+10]};
                            data_Y_w[129: 10*8] = {10'd0, data_Y_w[129: 10*8+10]};
                        end
                        9: begin
                            data_X_w[129: 10*9] = {10'd0, data_X_r[129: 10*9+10]};
                            data_Y_w[129: 10*9] = {10'd0, data_Y_w[129: 10*9+10]};
                        end
                        10: begin
                            data_X_w[129: 10*10] = {10'd0, data_X_r[129: 10*10+10]};
                            data_Y_w[129: 10*10] = {10'd0, data_Y_w[129: 10*10+10]};
                        end
                        default: begin
                            data_X_w = data_X_r;
                            data_Y_w = data_Y_r;
                        end
                    endcase
                end
            end
        end
        S_ADD_LAST : begin
            find_con_valid_w = 0;
            max_index_w = max_index_r + 1;
            data_X_w[10*curr_index_r+10 +:10] = Xn_r;
            data_Y_w[10*curr_index_r+10 +:10] = Yn_r;
            state_w = S_IDLE;
            curr_index_w = 5'd1;
            // data_X_w[129: 10*curr_index_r+20] = data_X_r[119: 10*curr_index_r+10];
            // data_Y_w[129: 10*curr_index_r+20] = data_Y_r[119: 10*curr_index_r+10];
            case (curr_index_r)
                1: begin
                    data_X_w[129: 10*1+20] = data_X_r[119: 10*1+10];
                    data_Y_w[129: 10*1+20] = data_Y_r[119: 10*1+10];
                end
                2: begin
                    data_X_w[129: 10*2+20] = data_X_r[119: 10*2+10];
                    data_Y_w[129: 10*2+20] = data_Y_r[119: 10*2+10];
                end
                3: begin
                    data_X_w[129: 10*3+20] = data_X_r[119: 10*3+10];
                    data_Y_w[129: 10*3+20] = data_Y_r[119: 10*3+10];
                end
                4: begin
                    data_X_w[129: 10*4+20] = data_X_r[119: 10*4+10];
                    data_Y_w[129: 10*4+20] = data_Y_r[119: 10*4+10];
                end
                5: begin
                    data_X_w[129: 10*5+20] = data_X_r[119: 10*5+10];
                    data_Y_w[129: 10*5+20] = data_Y_r[119: 10*5+10];
                end
                6: begin
                    data_X_w[129: 10*6+20] = data_X_r[119: 10*6+10];
                    data_Y_w[129: 10*6+20] = data_Y_r[119: 10*6+10];
                end
                7: begin
                    data_X_w[129: 10*7+20] = data_X_r[119: 10*7+10];
                    data_Y_w[129: 10*7+20] = data_Y_r[119: 10*7+10];
                end
                8: begin
                    data_X_w[129: 10*8+20] = data_X_r[119: 10*8+10];
                    data_Y_w[129: 10*8+20] = data_Y_r[119: 10*8+10];
                end
                9: begin
                    data_X_w[129: 10*9+20] = data_X_r[119: 10*9+10];
                    data_Y_w[129: 10*9+20] = data_Y_r[119: 10*9+10];
                end
                10: begin
                    data_X_w[129: 10*10+20] = data_X_r[119: 10*10+10];
                    data_Y_w[129: 10*10+20] = data_Y_r[119: 10*10+10];
                end
                default: begin
                    data_X_w = data_X_r;
                    data_Y_w = data_Y_r;
                end
            endcase
        end
    endcase
end

// input counter
always @(*) begin
    input_cnt_w = input_cnt_r;
    case (state_r)
    S_INPUT: begin
        if(input_cnt_r == 3'd4) begin
            input_cnt_w = 3'd0;
        end
        else begin
            input_cnt_w = input_cnt_r + 1;
        end
    end  
    endcase
end

// sequential
always @(posedge CLK or posedge RST) begin
    if(RST) begin
        state_r <= 0;
        READ_PT <= 0;
        input_cnt_r <= 0;
        Xn_r <= 10'd0;
        Yn_r <= 10'd0;
        max_index_r <= 4'd0;
        curr_index_r <= 4'd0;
        DROP_V <= 0;
        DROP_X <= 10'd0;
        DROP_Y <= 10'd0;
        data_X_r <= 130'd0;
        data_Y_r <= 130'd0;
        find_con_valid_r <= 0;
    end
    else begin
        state_r <= state_w;
        READ_PT <= READ_PT_w;
        input_cnt_r <= input_cnt_w;
        Xn_r <= Xn_w;
        Yn_r <= Yn_w;
        max_index_r <= max_index_w;
        curr_index_r <= curr_index_w;
        DROP_V <= DROP_V_w;
        DROP_X <= DROP_X_w;
        DROP_Y <= DROP_Y_w;
        data_X_r <= data_X_w;
        data_Y_r <= data_Y_w;
        find_con_valid_r <= find_con_valid_w;
    end
end

endmodule

module find_convex(
    input CLK,
    input RST,
    input i_valid,




    input [9:0] X1, Y1,
    input [9:0] X2, Y2,
    input [9:0] X3, Y3,
    input [9:0] Xn, Yn,
    output o_valid,
    output stop, pop, same,
    output [1:0] pop_index,
    output [1:0] same_index,
    output [1:0] stop_index
);
    reg [1:0] result_r [0:1][0:5], result_w[0:1][0:5];
    reg [9:0] X1_r, Y1_r, X2_r, Y2_r, X3_r, Y3_r, Xn_r, Yn_r;
    reg [9:0] X1_w, Y1_w, X2_w, Y2_w, X3_w, Y3_w, Xn_w, Yn_w;
    reg [2:0] state_r, state_w;
    wire comput_index;
    wire [1:0] result_temp [0:5];
    wire [9:0] X_test [0:5], Y_test[0:5];
    wire pop_1, pop_2, pop_3;
    wire stop_0, stop_1, stop_2, stop_3, stop_4, stop_5;
    wire same_0_0, same_0_1, same_1_0, same_1_1, same_2_0, same_2_1;




    parameter IDLE = 0, CAL0 = 1, CAL1 = 2, COMP = 3, DONE = 4;
    parameter BIGGER = 2'b10, SMALLER = 2'b01, SAME = 2'b11;




    integer i, j;
    // ========================Output========================
    //pop
    assign pop_1 =  (((result_r[0][0] == BIGGER) && (result_r[1][0] == SMALLER)) || ((result_r[0][0] == SMALLER) && (result_r[1][0] == BIGGER))) &&
                    (((result_r[0][1] == BIGGER) && (result_r[1][1] == SMALLER)) || ((result_r[0][1] == SMALLER) && (result_r[1][1] == BIGGER)));
    assign pop_2 =  (((result_r[0][2] == BIGGER) && (result_r[1][2] == SMALLER)) || ((result_r[0][2] == SMALLER) && (result_r[1][2] == BIGGER))) &&
                    (((result_r[0][3] == BIGGER) && (result_r[1][3] == SMALLER)) || ((result_r[0][3] == SMALLER) && (result_r[1][3] == BIGGER)));
    assign pop_3 =  (((result_r[0][4] == BIGGER) && (result_r[1][4] == SMALLER)) || ((result_r[0][4] == SMALLER) && (result_r[1][4] == BIGGER))) &&
                    (((result_r[0][5] == BIGGER) && (result_r[1][5] == SMALLER)) || ((result_r[0][5] == SMALLER) && (result_r[1][5] == BIGGER)));
    assign pop = pop_1 || pop_2 || pop_3;
    assign pop_index = (pop_1) ? 0 : (pop_2) ? 1 : 2;
    // stop
    assign stop_0 = ((result_r[0][0] == BIGGER) && (result_r[1][0] == BIGGER) || (result_r[0][0] == SMALLER) && (result_r[1][0] == SMALLER)) &&
                    ((result_r[0][1] == BIGGER) && (result_r[1][1] == SMALLER) || (result_r[0][1] == SMALLER) && (result_r[1][1] == BIGGER));
    assign stop_1 = ((result_r[0][0] == BIGGER) && (result_r[1][0] == SMALLER) || (result_r[0][0] == SMALLER) && (result_r[1][0] == BIGGER)) &&
                    ((result_r[0][1] == BIGGER) && (result_r[1][1] == BIGGER) || (result_r[0][1] == SMALLER) && (result_r[1][1] == SMALLER));
    assign stop_2 = ((result_r[0][2] == BIGGER) && (result_r[1][2] == BIGGER) || (result_r[0][2] == SMALLER) && (result_r[1][2] == SMALLER)) &&
                    ((result_r[0][3] == BIGGER) && (result_r[1][3] == SMALLER) || (result_r[0][3] == SMALLER) && (result_r[1][3] == BIGGER));
    assign stop_3 = ((result_r[0][2] == BIGGER) && (result_r[1][2] == SMALLER) || (result_r[0][2] == SMALLER) && (result_r[1][2] == BIGGER)) &&
                    ((result_r[0][3] == BIGGER) && (result_r[1][3] == BIGGER) || (result_r[0][3] == SMALLER) && (result_r[1][3] == SMALLER));
    // assign stop_4 = ((result_r[0][4] == BIGGER) && (result_r[1][4] == BIGGER) || (result_r[0][4] == SMALLER) && (result_r[1][4] == SMALLER)) &&
    //                 ((result_r[0][5] == BIGGER) && (result_r[1][5] == SMALLER) || (result_r[0][5] == SMALLER) && (result_r[1][5] == BIGGER));
    // assign stop_5 = ((result_r[0][4] == BIGGER) && (result_r[1][4] == SMALLER) || (result_r[0][4] == SMALLER) && (result_r[1][4] == BIGGER)) &&
    //                 ((result_r[0][5] == BIGGER) && (result_r[1][5] == BIGGER) || (result_r[0][5] == SMALLER) && (result_r[1][5] == SMALLER));
    // assign stop = ~pop && (((stop_0 || stop_1) && (stop_2 || stop_3)) || ((stop_2 || stop_3) && (stop_4 || stop_5)) || ((stop_0 || stop_1) && (stop_4 || stop_5)));
    assign stop = ~pop  && (((stop_0 || stop_1) && (stop_2 || stop_3)));
    assign stop_index  =   0;

    // same
    // assign same = 0;
    // assign same_index = 0;
    assign same_0_0 =   ((result_r[0][0] == BIGGER) && (result_r[1][0] == BIGGER) || (result_r[0][0] == SMALLER) && (result_r[1][0] == SMALLER)) &&
                        ((result_r[0][1] == SAME  ) || (result_r[1][1] == SAME  ));
    assign same_0_1 =   ((result_r[0][0] == BIGGER) && (result_r[1][0] == SMALLER) || (result_r[0][0] == SMALLER) && (result_r[1][0] == BIGGER)) &&
                        ((result_r[0][1] == SAME  ) || (result_r[1][1] == SAME  ));
    assign same_1_0 =   ((result_r[0][2] == BIGGER) && (result_r[1][2] == BIGGER) || (result_r[0][2] == SMALLER) && (result_r[1][2] == SMALLER)) &&
                        ((result_r[0][3] == SAME  ) || (result_r[1][3] == SAME  ));
    assign same_1_1 =   ((result_r[0][2] == BIGGER) && (result_r[1][2] == SMALLER) || (result_r[0][2] == SMALLER) && (result_r[1][2] == BIGGER)) &&
                        ((result_r[0][3] == SAME  ) || (result_r[1][3] == SAME  ));
    assign same_2_0 =   ((result_r[0][4] == BIGGER) && (result_r[1][4] == BIGGER) || (result_r[0][4] == SMALLER) && (result_r[1][4] == SMALLER)) &&
                        ((result_r[0][5] == SAME  ) || (result_r[1][5] == SAME  ));
    assign same_2_1 =   ((result_r[0][4] == BIGGER) && (result_r[1][4] == SMALLER) || (result_r[0][4] == SMALLER) && (result_r[1][4] == BIGGER)) &&
                        ((result_r[0][5] == SAME  ) || (result_r[1][5] == SAME  ));
    assign same = same_0_0 || same_0_1 || same_1_0 || same_1_1 || same_2_0 || same_2_1;
    assign same_index = (same_0_1)? 0:
                        (same_1_1)? 1:
                        (same_2_1)? 2: 3;




    // ========================FSM========================
    assign o_valid = (state_r == DONE);
    always @(*) begin
        state_w = state_r;
        case(state_r)
            IDLE: begin
                if(i_valid) begin
                    state_w = CAL0;
                end
            end
            CAL0: state_w = CAL1;
            CAL1: state_w = COMP;
            COMP: state_w = DONE;
            DONE: state_w = IDLE;
        endcase
    end
    // ==================combinential logic=========================
    assign comput_index = (state_r == CAL0) ? 1'b0 : 1'b1;
    assign {X_test[0], Y_test[0]} = (comput_index) ? {Xn_r, Yn_r} : {X3_w, Y3_w};
    assign {X_test[1], Y_test[1]} = (comput_index) ? {Xn_r, Yn_r} : {X2_w, Y2_w};
    assign {X_test[2], Y_test[2]} = (comput_index) ? {Xn_r, Yn_r} : {X3_w, Y3_w};
    assign {X_test[3], Y_test[3]} = (comput_index) ? {Xn_r, Yn_r} : {X1_w, Y1_w};
    assign {X_test[4], Y_test[4]} = (comput_index) ? {Xn_r, Yn_r} : {X2_w, Y2_w};
    assign {X_test[5], Y_test[5]} = (comput_index) ? {Xn_r, Yn_r} : {X1_w, Y1_w};
    linear_func f1(X1_r, Y1_r, X2_r, Y2_r, X_test[0], Y_test[0], result_temp[0]); //1 2
    linear_func f2(X1_r, Y1_r, X3_r, Y3_r, X_test[1], Y_test[1], result_temp[1]); //1 3
    linear_func f3(X2_r, Y2_r, X1_r, Y1_r, X_test[2], Y_test[2], result_temp[2]); //2 1
    linear_func f4(X2_r, Y2_r, X3_r, Y3_r, X_test[3], Y_test[3], result_temp[3]); //2 3
    linear_func f5(X3_r, Y3_r, X1_r, Y1_r, X_test[4], Y_test[4], result_temp[4]); //3 1
    linear_func f6(X3_r, Y3_r, X2_r, Y2_r, X_test[5], Y_test[5], result_temp[5]); //3 2




    always @(*) begin
        for (i = 0; i < 2 ;i = i +1 ) begin
                for (j = 0; j < 6; j = j + 1) begin
                    result_w[i][j] = result_r[i][j];
                end
            end
        for (i = 0;i < 6 ; i = i + 1) begin
            result_w[comput_index][i] = result_temp[i];
        end
    end
    always @(*) begin
        X1_w = X1_r;
        Y1_w = Y1_r;
        X2_w = X2_r;
        Y2_w = Y2_r;
        X3_w = X3_r;
        Y3_w = Y3_r;
        Xn_w = Xn_r;
        Yn_w = Yn_r;
        if(i_valid) begin
            X1_w = X1;
            Y1_w = Y1;
            X2_w = X2;
            Y2_w = Y2;
            X3_w = X3;
            Y3_w = Y3;
            Xn_w = Xn;
            Yn_w = Yn;
        end
    end




    // ==================sequential logic=========================
    always @(posedge CLK or posedge RST) begin
        if(RST) begin
            state_r <= IDLE;
            X1_r <= 0;
            Y1_r <= 0;
            X2_r <= 0;
            Y2_r <= 0;
            X3_r <= 0;
            Y3_r <= 0;
            Xn_r <= 0;
            Yn_r <= 0;
            for (i = 0; i < 2 ;i = i +1 ) begin
                for (j = 0; j < 6; j = j + 1) begin
                    result_r[i][j] <= 0;
                end
            end
        end
        else begin
            state_r <= state_w;
            X1_r <= X1_w;
            Y1_r <= Y1_w;
            X2_r <= X2_w;
            Y2_r <= Y2_w;
            X3_r <= X3_w;
            Y3_r <= Y3_w;
            Xn_r <= Xn_w;
            Yn_r <= Yn_w;
            for (i = 0; i < 2 ;i = i +1 ) begin
                for (j = 0; j < 6; j = j + 1) begin
                    result_r[i][j] <= result_w[i][j];
                end
            end
        end
    end
endmodule


module linear_func(
    input [9:0] X1, Y1,
    input [9:0] X2, Y2,
    input [9:0] iX, iY,
    output [1:0] result
);
    parameter BIGGER = 2'b10, SMALLER = 2'b01, SAME = 2'b11;
    wire signed [10:0] delta_x, delta_y;
    wire signed [10:0] delta_x1, delta_y1;
    wire signed [21:0] mul_1, mul_2;
    assign delta_x = X2 - X1;
    assign delta_y = Y2 - Y1;
    assign delta_x1 = iX - X1;
    assign delta_y1 = iY - Y1;
    assign mul_1 = delta_x * delta_y1;
    assign mul_2 = delta_y * delta_x1;
    assign result = (mul_1 == mul_2) ? SAME : (mul_1 > mul_2) ? BIGGER : SMALLER;
endmodule

