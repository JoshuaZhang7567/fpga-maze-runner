// action: {release, key}, held for 1 cycle per key event; 1111 = no action
module key_decoder(clock, data, data_valid, action, resetn);
    input clock, data_valid, resetn;
    input [7:0] data;
    output reg [3:0] action;

    reg releasing; // 1 if the previous byte was F0

    always @(posedge clock) begin
        if (!resetn)
            releasing <= 1'b0;
        else if (data_valid) begin
            if (data == 8'hF0)
                releasing <= 1'b1;
            else
                releasing <= 1'b0;
        end
    end

    reg [2:0] key;
    reg known;

    always @(*) begin
        known = 1'b1;
        case (data)
            8'h1D, 8'h75: key = 3'b000; // W, Up
            8'h1C, 8'h6B: key = 3'b001; // A, Left
            8'h1B, 8'h72: key = 3'b010; // S, Down
            8'h23, 8'h74: key = 3'b011; // D, Right
            8'h29:        key = 3'b100; // Space
            default: begin
                key   = 3'b000;
                known = 1'b0;
            end
        endcase

        if (data_valid && known)
            action = {releasing, key};
        else
            action = 4'b1111;
    end
endmodule
