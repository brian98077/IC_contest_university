module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output reg IROM_rd;
output reg [5:0] IROM_A;
output reg IRAM_valid;
output reg [7:0] IRAM_D;
output reg [5:0] IRAM_A;
output reg busy;
output reg done;

//my code
reg [7:0] data [0:63];
reg [6:0] i,j;
reg [5:0] max_position, min_position;
reg [9:0] average;

// current status
reg [1:0] status;
parameter [1:0] initialization = 0, command = 1, WRITE = 2, operation = 3;

//command
parameter [3:0] write = 0, up = 1, down = 2, left = 3, right = 4, max = 5, min = 6, avg = 7, ccrotate = 8, crotate = 9, mirrorx = 10, mirrory = 11;

//position
reg [5:0] leftup; 
wire [5:0]leftdown, rightup, rightdown;
assign leftdown = leftup + 6'd8;
assign rightup = leftup + 6'd1;
assign rightdown = leftup + 6'd9;

//algorithm
always @(posedge clk or posedge reset) begin
    
    if(reset)
    begin
        //$display ("check 0");
        status <= initialization;
        done <= 1'b0;
        busy <= 1'b1;
        IROM_rd <= 1'b1;
        leftup <= 6'h1b;
        IROM_A <= 6'd0;
        j <= 6'd0;
        for(i=0;i<64;i=i+1)
            data[i] <= 8'd0;
    end
    else
    begin
        if(status == initialization)begin
            //$display ("check 1");
            if(IROM_A == 6'd63) begin
                IROM_rd <= 1'd0;
                busy <= 1'b0;
            end
            else IROM_A <= IROM_A + 6'd1;
            data[IROM_A] <= IROM_Q;
            //if(done) status <= WRITE;
            if(cmd_valid) begin
                status <= command;
                //$display("check 55555555555");
                busy <= 1'b1;
            end
        end
        if(status == WRITE)begin
            //$display ("check 2");
            IRAM_valid <= 1'b1;
            j <= ( j == 6'd63 )? 6'd63 : j + 6'd1;
            IRAM_A <= j;
            IRAM_D <= data[j];
        end
        if(status == command)begin
            busy <= 1'b1;
            status <= operation;
        end

        if(status == operation)begin
                //$display ("check 3");
                case(cmd)
                    write:
                    begin
                        status <= WRITE;
                    end
                    up: 
                    begin
                        if(leftup > 6'd7) leftup <= leftup - 6'd8;
                        busy <= 1'b0;
                        status <= command;
                    end
                    
                    down : 
                    begin
                        if(leftup < 6'h30) leftup <= leftup + 6'd8;
                        busy <= 1'b0;
                        status <= command;
                    end
                    left :
                    begin
                        if(leftup != 6'h0 && leftup != 6'h8 && leftup != 6'h10 && leftup != 6'h18 && leftup != 6'h20 && leftup != 6'h28 && leftup != 6'h30 && leftup != 6'h38) leftup <= leftup - 6'd1;
                        busy <= 1'b0;
                        status <= command;
                    end 
                    right : 
                    begin
                        if(leftup != 6'h6 && leftup != 6'he && leftup != 6'h16 && leftup != 6'h1e && leftup != 6'h26 && leftup != 6'h2e && leftup != 6'h36 && leftup != 6'h3e) leftup <= leftup + 6'd1;
                        busy <= 1'b0;
                        status <= command;
                    end
                    max : 
                    begin
                        data[leftup] <= data[max_position];
                        data[leftdown] <= data[max_position];
                        data[rightdown] <= data[max_position];
                        data[rightup] <= data[max_position];
                        busy <= 1'b0;
                        status <= command;
                    end
                    min:
                    begin
                        data[leftup] <= data[min_position];
                        data[leftdown] <= data[min_position];
                        data[rightdown] <= data[min_position];
                        data[rightup] <= data[min_position];
                        busy <= 1'b0;
                        status <= command;
                    end
                    avg:
                    begin
                        data[leftup] <= average[9:2];
                        data[leftdown] <= average[9:2];
                        data[rightdown] <= average[9:2];
                        data[rightup] <= average[9:2];
                        busy <= 1'b0;
                        status <= command;
                    end
                    ccrotate:
                    begin
                        data[leftup] <= data[rightup];
                        data[leftdown] <= data[leftup];
                        data[rightdown] <= data[leftdown];
                        data[rightup] <= data[rightdown];
                        busy <= 1'b0;
                        status <= command;
                    end
                    crotate:
                    begin
                        data[leftup] <= data[leftdown];
                        data[leftdown] <= data[rightdown];
                        data[rightdown] <= data[rightup];
                        data[rightup] <= data[leftup];
                        busy <= 1'b0;
                        status <= command;
                    end
                    mirrorx:
                    begin
                        data[leftup] <= data[leftdown];
                        data[leftdown] <= data[leftup];
                        data[rightdown] <= data[rightup];
                        data[rightup] <= data[rightdown];
                        busy <= 1'b0;
                        status <= command;
                    end
                    mirrory:
                    begin
                        data[leftup] <= data[rightup];
                        data[leftdown] <= data[rightdown];
                        data[rightdown] <= data[leftdown];
                        data[rightup] <= data[leftup];
                        busy <= 1'b0;
                        status <= command;
                    end
                endcase
            end

        if(status == WRITE && IRAM_A == 6'd63)begin
            //$display("check44444444444444444444");
            busy <= 1'b0;
            done <= 1'b1;
            IRAM_valid <= 1'b0;
            //status <= initialization;
        end
    end
end

// arithmetic
always @(*) begin
    average = data[leftup] + data[leftdown] + data[rightdown] + data[rightup];

	if(data[leftup] >= data[rightup] && data[leftup] >= data[leftdown] && data[leftup] >= data[rightdown]) max_position = leftup;
	else if(data[rightup] >= data[leftup] && data[rightup] >= data[leftdown] && data[rightup] >= data[rightdown]) max_position = rightup;
	else if(data[leftdown] >= data[leftup] && data[leftdown] >= data[rightup] && data[leftdown] >= data[rightdown]) max_position = leftdown;
	else max_position = rightdown;

    if( data[leftup] <= data[rightup] && data[leftup] <= data[leftdown] && data[leftup] <= data[rightdown] ) min_position = leftup;
	else if( data[rightup] <= data[leftup] && data[rightup] <= data[leftdown] && data[rightup] <= data[rightdown] ) min_position = rightup;
	else if( data[leftdown] <= data[leftup] && data[leftdown] <= data[rightup] && data[leftdown] <= data[rightdown] ) min_position = leftdown;
	else min_position = rightdown;
end
endmodule



