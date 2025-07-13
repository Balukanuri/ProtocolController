`timescale 1ns/1ps

module testbench;

    reg clk;
    reg reset;
    reg [1:0] protocol_select;
    reg [7:0] data_in;

    wire [7:0] data_out;
    wire busy;
    wire done;
    wire [1:0] protocol_active;
    wire [1:0] debug_cycle_count;
    wire [2:0] debug_state;

    protocol_controller dut (
        .clk(clk),
        .reset(reset),
        .protocol_select(protocol_select),
        .data_in(data_in),
        .data_out(data_out),
        .busy(busy),
        .done(done),
        .protocol_active(protocol_active),
        .debug_cycle_count(debug_cycle_count),
        .debug_state(debug_state)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task run_protocol(input [1:0] proto, input [7:0] din, input [7:0] expected);
        begin
            @(negedge clk);
            protocol_select <= proto;
            data_in <= din;

            repeat (3) @(negedge clk);

            protocol_select <= 2'b00;
            data_in <= 8'h00;

            wait (done == 1);

            if (data_out !== expected) begin
                $display("❌ FAIL: Proto %b, Input %h → Expected %h, Got %h at time %0t",
                         proto, din, expected, data_out, $time);
                $fatal;
            end else begin
                $display("✅ PASS: Proto %b, Input %h → Output %h at time %0t",
                         proto, din, data_out, $time);
            end

            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, testbench);

        reset = 1;
        protocol_select = 2'b00;
        data_in = 8'd0;

        repeat (2) @(negedge clk);
        reset = 0;

        run_protocol(2'b01, 8'h11, 8'h12);
        run_protocol(2'b10, 8'h0F, ~8'h0F);
        run_protocol(2'b11, 8'h55, 8'hFF);

        $display("\n🎉 All tests passed!");
        $finish;
    end

endmodule
Add testbench from EDA Playground
