module geofence ( clk,reset,X,Y,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
output valid;
output is_inside;


parameter state_READ = 2'd0;
parameter state_SORT = 2'd1;
parameter state_COMP = 2'd2;
parameter state_RETN = 2'd3;
//declare
reg [2:0] state, nxt_state;
reg [3:0] counter, nxt_counter;
reg [2:0] pos1, pos2, pos0, pos3; // For sorting


wire signed [10:0] vertex1_X;
wire signed [10:0] vertex1_Y;
wire signed [10:0] vertex2_X;
wire signed [10:0] vertex2_Y;


wire signed [20:0] product; //�~�n
reg [9:0] POS_X [6:0];
reg [9:0] POS_Y [6:0];
reg unmatch, direction;
integer i;
//-----------------wire assignment-------------
assign valid = (state == state_RETN)? 1 :0;
assign is_inside = ~unmatch;


//function
//------------------FSM------------------
always @(*) begin
    case (state)
        state_READ: nxt_state = (counter == 4'd7)? state_SORT: state_READ;
        state_SORT: nxt_state = (counter == 4'd9)? state_COMP: state_SORT;
        state_COMP: nxt_state = (unmatch || counter == 4'd5)? state_RETN: state_COMP;
        state_RETN: nxt_state = state_READ;
        default: nxt_state = state;
    endcase
end
always @(posedge clk or posedge reset) begin
    if(reset)
        state <= state_READ;
    else
        state <= nxt_state;
end


//------------------counter--------------
always @(*) begin
    case (state)
        state_READ: nxt_counter = (nxt_state == state_READ) ? counter + 1 : 0;
        state_SORT: nxt_counter = (nxt_state == state_SORT) ? counter + 1 : 0;
        state_COMP: nxt_counter = (nxt_state == state_COMP) ? counter + 1 : 0;
        state_RETN: nxt_counter = 0;
        default: nxt_counter = counter;
    endcase
end
// always @(*) begin
//     nxt_counter1 = (state == state_RETN) ? 0 : ((state == state_READ)? counter1 + 1: counter1);
//     nxt_counter2 = (state == state_RETN) ? 0 : ((state == state_SORT)? counter2 + 1: counter2);
//     nxt_counter3 = (state == state_RETN) ? 0 : ((state == state_COMP)? counter3 + 1: counter3);
// end
always @(posedge clk or posedge reset) begin
    if(reset) begin
        counter <= 0;
        // counter2 <= 0;
        // counter3 <= 0;
    end
    else begin
        counter <= nxt_counter;
        // counter2 <= nxt_counter2;
        // counter3 <= nxt_counter3;
    end
end

//---------------Sorting-----------------------
assign vertex1_X = POS_X[pos1] - POS_X[pos0];
assign vertex1_Y = POS_Y[pos1] - POS_Y[pos0];
assign vertex2_X = POS_X[pos2] - POS_X[pos3];
assign vertex2_Y = POS_Y[pos2] - POS_Y[pos3];
assign product = vertex1_X * vertex2_Y - vertex2_X * vertex1_Y;


always @(posedge clk) begin
    if(nxt_state == state_SORT) begin
        case (nxt_counter)
            0: begin
                pos1 <= 2;
                pos2 <= 3;
                pos0 <= 1;
                pos3 <= 1;
            end
            1:begin
                pos1 <= 2;
                pos2 <= 4;
                pos0 <= 1;
                pos3 <= 1;
            end
            2:begin
                pos1 <= 2;
                pos2 <= 5;
                pos0 <= 1;
                pos3 <= 1;
            end
            3:begin
                pos1 <= 2;
                pos2 <= 6;
                pos0 <= 1;
                pos3 <= 1;
            end
            4:begin
                pos1 <= 3;
                pos2 <= 4;
                pos0 <= 1;
                pos3 <= 1;
            end
            5:begin
                pos1 <= 3;
                pos2 <= 5;
                pos0 <= 1;
                pos3 <= 1;
            end
            6:begin
                pos1 <= 3;
                pos2 <= 6;
                pos0 <= 1;
                pos3 <= 1;
            end
            7:begin
                pos1 <= 4;
                pos2 <= 5;
                pos0 <= 1;
                pos3 <= 1;
            end
            8:begin
                pos1 <= 4;
                pos2 <= 6;
                pos0 <= 1;
                pos3 <= 1;
            end
            9:begin
                pos1 <= 5;
                pos2 <= 6;
                pos0 <= 1;
                pos3 <= 1;
            end
            default: begin
                pos1 <= pos1;
                pos2 <= pos2;
                pos0 <= 1;
                pos3 <= 1;
            end
        endcase
    end
    else if(nxt_state == state_COMP)begin
        if(counter != 3'd4) begin
            pos1 <= nxt_counter + 3'd1;
            pos2 <= nxt_counter + 3'd2;
            pos0 <= 0;
            pos3 <= nxt_counter + 3'd1;
        end
        else if(counter == 3'd4) begin
            pos0 <= 3'd0;
            pos1 <= 3'd6;
            pos2 <= 3'd1;
            pos3 <= 3'd6;
        end
    end
end


//read
always @(posedge clk) begin
    if(state == state_READ)begin
        POS_X[counter] <= X;
        POS_Y[counter] <= Y;
    end
    else if(state == state_SORT) begin
        POS_X[pos1] <= (product[20]) ? POS_X[pos1]: POS_X[pos2];
        POS_Y[pos1] <= (product[20]) ? POS_Y[pos1]: POS_Y[pos2];
        POS_X[pos2] <= (product[20]) ? POS_X[pos2]: POS_X[pos1];
        POS_Y[pos2] <= (product[20]) ? POS_Y[pos2]: POS_Y[pos1];
    end
end

always @(posedge clk) begin
    if(state == state_COMP) begin
        direction <= product[20];
    end
end
always @(posedge clk) begin
    if(state == state_COMP)begin
            unmatch <= (counter != 0)? ((unmatch) ? 1 : ((product[20] != direction) ? 1: 0)):  0;
    end
    else if(state == state_READ)
        unmatch <= 0;
    else
        unmatch <= unmatch;
end
endmodule