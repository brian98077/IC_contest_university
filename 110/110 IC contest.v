module JAM (
input CLK,
input RST,
output reg [2:0] W,
output reg [2:0] J,
input [6:0] Cost,
output reg [3:0] MatchCount,
output reg [9:0] MinCost,
output Valid );
//================================================================
//  integer / genvar / parameters
//================================================================
parameter  state_STEP1 = 3'd0;
parameter  state_STEP2 = 3'd1;
parameter  state_FLIP  = 3'd2;
parameter  state_READ  = 3'd3;
parameter  state_COMP  = 3'd4;
parameter  state_OUT   = 3'd5;
parameter  state_IDLE   = 3'd6;
//================================================================
//  Wires & Registers
//================================================================
reg [2:0] state, nxt_state;
wire find, find_min, last;
reg [9:0] curr_cost;
reg [2:0] i, j;
reg [2:0] worker [7:0]; // i-th worker do worker[i]-th job
//================================================================
//  design
//================================================================
//------assignment---------


assign last = (worker[0] == 3'd7 && worker[1] ==  3'd6 && worker[2] ==  3'd5 && worker[3] ==  3'd4 && worker[4] ==  3'd3 && worker[5] == 3'd2 && worker[6] == 3'd1 && worker[7] == 3'd0) ? 1 : 0;
assign find = (state == state_STEP1) ? ((worker[i] < worker[i+1]) ? 1: 0 ): 0;
assign find_min = (state == state_STEP2) ? ((j == i)? 1 : 0) : 0;
assign Valid = (state == state_OUT)?1:0;

//------FSM----------------
always @(*) begin
    case (state)
        state_STEP1: nxt_state = (find)? state_STEP2: state_STEP1;
        state_STEP2: nxt_state = (find_min)? state_FLIP: state_STEP2;
        state_FLIP:  nxt_state = state_READ;
        state_READ:  nxt_state = (W == 7) ? state_COMP: state_READ;
        state_COMP:  nxt_state = (last)? state_OUT: state_STEP1;
        state_IDLE:  nxt_state = (~RST)? state_READ: state_IDLE;
        default: nxt_state = state;
    endcase
end
always @(posedge CLK) begin
    if(RST) begin
        state <= state_IDLE;
    end
    else begin
        state <= nxt_state;
    end
end

//step 1
always @(posedge CLK) begin
    if(state == state_IDLE) i <= 3'd6;
    else if(state == state_STEP1) i <= (find) ? i: i - 1;
    else if(state == state_COMP) i <= 3'd6;
    else i <= i;
end


reg [2:0] min_idx;
reg flag;
// step 2
always @(posedge CLK) begin
    if(state == state_IDLE) j <= 3'd7;
    else if(state == state_STEP2 && j != i ) j <= j - 1;
    else if(state == state_STEP1) j <= 3'd7;
    else j <= j;
end
always @(posedge CLK) begin
    if(state == state_STEP1) begin
        min_idx <= 3'd7;
        flag <= 1;
    end
    else if(state == state_STEP2)begin
        if(worker[j] > worker[i] && flag) begin
            min_idx <= j;
            flag <= 0;
        end
        else if(worker[j] > worker[i] && worker[min_idx] > worker[j] && ~flag) begin
            min_idx <= j;
        end
        else min_idx <= min_idx;
    end
end


//  step2 swap and flip
always @(posedge CLK) begin
    if(state == state_IDLE) begin
        worker[0] <= 3'd0;
        worker[1] <= 3'd1;
        worker[2] <= 3'd2;
        worker[3] <= 3'd3;
        worker[4] <= 3'd4;
        worker[5] <= 3'd5;
        worker[6] <= 3'd6;
        worker[7] <= 3'd7;
    end
    else if(state == state_STEP2 && find_min)begin
        worker[i] <= worker[min_idx];
        worker[min_idx] <= worker[i];
    end
    else if(state == state_FLIP) begin
        case (i)
            3'd0: begin
                worker[0] <= worker[0];
                worker[1] <= worker[7];
                worker[2] <= worker[6];
                worker[3] <= worker[5];
                worker[4] <= worker[4];
                worker[5] <= worker[3];
                worker[6] <= worker[2];
                worker[7] <= worker[1];
            end
            3'd1: begin
                worker[0] <= worker[0];
                worker[1] <= worker[1];
                worker[2] <= worker[7];
                worker[3] <= worker[6];
                worker[4] <= worker[5];
                worker[5] <= worker[4];
                worker[6] <= worker[3];
                worker[7] <= worker[2];
            end
            3'd2: begin
                worker[0] <= worker[0];
                worker[1] <= worker[1];
                worker[2] <= worker[2];
                worker[3] <= worker[7];
                worker[4] <= worker[6];
                worker[5] <= worker[5];
                worker[6] <= worker[4];
                worker[7] <= worker[3];
            end
            3'd3: begin
                worker[0] <= worker[0];
                worker[1] <= worker[1];
                worker[2] <= worker[2];
                worker[3] <= worker[3];
                worker[4] <= worker[7];
                worker[5] <= worker[6];
                worker[6] <= worker[5];
                worker[7] <= worker[4];
            end
            3'd4: begin
                worker[0] <= worker[0];
                worker[1] <= worker[1];
                worker[2] <= worker[2];
                worker[3] <= worker[3];
                worker[4] <= worker[4];
                worker[5] <= worker[7];
                worker[6] <= worker[6];
                worker[7] <= worker[5];
            end
            3'd5: begin
                worker[0] <= worker[0];
                worker[1] <= worker[1];
                worker[2] <= worker[2];
                worker[3] <= worker[3];
                worker[4] <= worker[4];
                worker[5] <= worker[5];
                worker[6] <= worker[7];
                worker[7] <= worker[6];
            end
            3'd6: begin
                worker[0] <= worker[0];
                worker[1] <= worker[1];
                worker[2] <= worker[2];
                worker[3] <= worker[3];
                worker[4] <= worker[4];
                worker[5] <= worker[5];
                worker[6] <= worker[6];
                worker[7] <= worker[7];
            end
            default: begin
                worker[0] <= worker[0];
                worker[1] <= worker[1];
                worker[2] <= worker[2];
                worker[3] <= worker[3];
                worker[4] <= worker[4];
                worker[5] <= worker[5];
                worker[6] <= worker[6];
                worker[7] <= worker[7];
            end
        endcase
    end
    else begin
        worker[0] <= worker[0];
        worker[1] <= worker[1];
        worker[2] <= worker[2];
        worker[3] <= worker[3];
        worker[4] <= worker[4];
        worker[5] <= worker[5];
        worker[6] <= worker[6];
        worker[7] <= worker[7];
    end
end




always @(CLK) begin
    if(state == state_IDLE) begin
        W <= 0;
        J <= 0;
    end
    else if(state == state_FLIP)begin
        W <= 3'd0;
        J <= worker[0];
    end
    // else if(state == state_READ && W == 7)begin
    //     W <= 3'd0;
    //     J <= worker[0];
    // end
    else if(state == state_READ && W != 7)begin
        W <= W + 1;
        J <= worker[W+1];
    end
    else begin
        W <= W;
        J <= J;
    end
end
//----Comp---------------
wire [1:0] compare;
//compare = 2: less cost; compare = 1: same cost; compare = 0: keep min cost;
assign compare =(MinCost >  curr_cost) ? 2:
                (MinCost == curr_cost) ? 1: 0;




always @(posedge CLK) begin
    if(state == state_IDLE) begin
        MatchCount <= 1;
        MinCost <= 1023;
    end
    else begin
        if(state == state_COMP) begin
            case (compare)
                2: begin
                    MinCost <= curr_cost;
                    MatchCount <= 1;
                end
                1: begin
                    MinCost <= MinCost;
                    MatchCount <= MatchCount + 1;
                end
                0: begin
                    MinCost <= MinCost;
                    MatchCount <= MatchCount;
                end
                default: begin
                    MinCost <= MinCost;
                    MatchCount <= MatchCount;
                end
            endcase
        end
        else begin
            MinCost <= MinCost;
            MatchCount <= MatchCount;
        end
    end
end
//------Cost--------------
always @(CLK) begin
    case (state)
        state_READ: begin
            curr_cost <= curr_cost + Cost;
        end
        state_COMP: curr_cost <= curr_cost;
        default: curr_cost <= 0;
    endcase
end


endmodule