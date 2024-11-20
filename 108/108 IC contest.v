
module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);

input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output reg match;
output reg[4:0] match_index;
output reg valid;

//my code

reg [7:0] buffer;
reg [7:0] data_string [31:0];
reg [7:0] data_pattern [31:0];
reg [4:0] index_read, index_string, index_pattern, len_string, len_pattern; // len = real length -1

// current state
reg [2:0] state, next_state;
parameter state_idle = 0, state_string = 1, state_pattern = 2, state_compare = 3;


//FSM

always @(posedge clk or posedge reset) begin
    if(reset) state <= state_idle;
    else state <= next_state;
end

always @(*) begin
    case (state)

        state_idle: begin
            if(isstring) next_state <= state_string;
            else if(ispattern) next_state <= state_pattern;
            else next_state <= state_idle;
        end
        
        state_string: begin
            if(isstring) next_state <= state_string;
            else if(ispattern) next_state <= state_pattern;
            else next_state <= state_idle;
        end

        state_pattern: begin
            if(ispattern) next_state <= state_pattern;
            else next_state <= state_compare;
        end

        state_compare: begin
            if(valid) next_state <= state_idle;
        end

        default: next_state <= state_idle;
    endcase
end


// control signals
always @(posedge clk) begin
    if(valid && state == state_idle) begin
        valid <= 0;
        match <= 0;
    end    
end

//buffer
always @(posedge clk or posedge reset) begin
    buffer <= chardata;
end


// index read
always @(posedge clk or posedge reset) begin
    if(reset) index_read <= 7'd0;
    else if( (state == state_string && next_state == state_pattern) || (state == state_pattern && next_state == state_compare) ) index_read <= 7'd0;
    else if(state == state_string || state == state_pattern) index_read <= index_read + 1;
    else index_read <= 7'd0;
end


// length of string
always @(posedge clk or posedge reset) begin
    if(reset) len_string <= 5'd0;
    else if(isstring) len_string <= len_string + 1;
end

// length of pattern
always @(posedge clk or posedge reset) begin
    if(reset) len_pattern <= 5'd0;
    else if(ispattern) len_pattern <= len_pattern + 1;
    else if(valid) len_pattern <= 5'd0;
end

// initialize string and pattern index
always @(posedge clk or posedge reset) begin
    if(reset) begin
        index_string <= 5'd0;
        index_pattern <= 5'd0;
    end
end

// algorithm

// read
always @(posedge clk or posedge reset) begin
    if(state == state_string) data_string[index_read] <= buffer;
    else if(state == state_pattern) data_pattern[index_read] <= buffer;
end

// matching index
always @(posedge clk or posedge reset) begin
    if(reset) match_index <= 5'd0;
    else if (index_pattern == 5'd0 || data_pattern[index_pattern] == 8'h5E) begin
        match_index <= index_string;
    end
    else match_index <= match_index;
end


//compare
always @(posedge clk or posedge reset) begin
    if(state == state_compare)begin
        if(index_string == len_string)begin // string ends
            if((data_string[index_string] == data_pattern[index_pattern] || data_pattern[index_pattern] == 8'h2E) && index_pattern == len_pattern || data_pattern[index_pattern+1] == 8'h24)begin // end with &
                valid <= 1;
                match <= 1;
                index_string <= 5'd0;
                index_pattern <= 5'd0;
            end
            else begin
                valid <= 1;
                match <= 0;
                index_string <= 5'd0;
                index_pattern <= 5'd0;
            end
        end
        else if(data_pattern[index_pattern] == 8'h24)begin // end with $ 
            if((data_string[index_string] == data_pattern[index_pattern] || data_pattern[index_pattern] == 8'h2E) && data_string[index_string+1] == 8'h20)begin // next character in string is space
                valid <= 1;
                match <= 1;
                index_string <= 5'd0;
                index_pattern <= 5'd0;
            end
            else begin
                valid <= 1;
                match <= 0;
                index_string <= 5'd0;
                index_pattern <= 5'd0;
            end
        end
        else if(data_pattern[index_pattern] == 8'h5E)begin // start with ^
            if(index_string == 0 || data_string[index_string-1] == 8'h20)begin// previous chatacter is space
                index_pattern <= index_pattern + 1;
                index_string <= index_string;
            end
            else begin
                index_string <= index_string;
                index_pattern <= 5'd0;
            end
        end
        else if((data_pattern[index_pattern] == data_string[index_string] || data_pattern[index_pattern] == 8'h2E) && index_pattern == len_pattern)begin
                valid <= 1;
                match <= 1;
                index_string <= 5'd0;
                index_pattern <= 5'd0;
        end
        else if(data_pattern[index_pattern] == data_string[index_string] || data_pattern[index_pattern] == 8'h2E)begin
            index_pattern <= index_pattern + 1;
            index_string <= index_string + 1;
        end
        else if(data_pattern[index_pattern] != data_string[index_string])begin
            index_pattern <= 8'd0;
            index_string <= index_string + 1;
            valid <= 1;
            match <= 0;
        end
    end
end

endmodule
