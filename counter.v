// n-bit wide step counter
module counter(resetn, clock, init, limit, step, enable, z, pulse);
    parameter W = 10;
    input resetn, clock, enable;

    // init: initial number that the counter start counting
    // limit: upper limit
    // step: increment of each posedge clk
    input [W-1:0] init, limit, step;

    // z: current count
    output reg [W-1:0] z;

    // 1 if it reaches limit, otherwise 0;
    output pulse;

    assign pulse = (z == limit);

    always @ (posedge clock) begin
        if(!resetn)
            z <= init;
        else if(enable) begin
            if(z == limit)
                z <= init;
            else
                z <= z+step;
        end
    end
endmodule
