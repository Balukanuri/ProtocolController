`timescale 1ns/1ps

module protocol_controller (
    input clk,
    input reset,
    input [1:0] protocol_select,
    input [7:0] data_in,
    output reg [7:0] data_out,
    output reg busy,
    output reg done,
    output reg [1:0] protocol_active,
    output reg [1:0] debug_cycle_count,
    output reg [2:0] debug_state
);

    // Protocol Types
    localparam PROTO_NONE = 2'b00;
    localparam PROTO_A    = 2'b01;
    localparam PROTO_B    = 2'b10;
    localparam PROTO_C    = 2'b11;

    // FSM States
    localparam IDLE       = 3'b000;
    localparam PROTOCOL_A = 3'b001;
    localparam WAIT_A     = 3'b010;
    localparam PROTOCOL_B = 3'b011;
    localparam WAIT_B     = 3'b100;
    localparam PROTOCOL_C = 3'b101;
    localparam WAIT_C     = 3'b110;

    // Internal registers
    reg [2:0] current_state, next_state;
    reg [1:0] cycle_count;
    reg [1:0] selected_proto;
    reg [7:0] latched_data;
    reg [7:0] result;

    // FSM State Register
    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // FSM Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                case (protocol_select)
                    PROTO_A: next_state = PROTOCOL_A;
                    PROTO_B: next_state = PROTOCOL_B;
                    PROTO_C: next_state = PROTOCOL_C;
                    default: next_state = IDLE;
                endcase
            end
            PROTOCOL_A: next_state = WAIT_A;
            PROTOCOL_B: next_state = WAIT_B;
            PROTOCOL_C: next_state = WAIT_C;
            WAIT_A:     next_state = (cycle_count == 2) ? IDLE : WAIT_A;
            WAIT_B:     next_state = (cycle_count == 2) ? IDLE : WAIT_B;
            WAIT_C:     next_state = (cycle_count == 2) ? IDLE : WAIT_C;
            default:    next_state = IDLE;
        endcase
    end

    // Cycle Counter Logic
    always @(posedge clk or posedge reset) begin
        if (reset)
            cycle_count <= 2'd0;
        else if (current_state == WAIT_A || current_state == WAIT_B || current_state == WAIT_C)
            cycle_count <= cycle_count + 1;
        else
            cycle_count <= 2'd0;
    end

    // Latch protocol and data
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            selected_proto <= PROTO_NONE;
            latched_data   <= 8'd0;
        end else begin
            case (current_state)
                PROTOCOL_A, PROTOCOL_B, PROTOCOL_C: begin
                    selected_proto <= protocol_select;
                    latched_data   <= data_in;
                end
            endcase
        end
    end

    // Protocol Execution Task
    task automatic do_protocol(input [1:0] proto, input [7:0] din, output [7:0] dout);
        begin
            case (proto)
                PROTO_A: dout = din + 8'd1;
                PROTO_B: dout = ~din;
                PROTO_C: dout = din ^ 8'hAA;
                default: dout = 8'd0;
            endcase
        end
    endtask

    // Output Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_out <= 8'd0;
            busy     <= 0;
            done     <= 0;
            protocol_active <= PROTO_NONE;
        end else begin
            done <= 0;
            case (current_state)
                PROTOCOL_A, PROTOCOL_B, PROTOCOL_C,
                WAIT_A, WAIT_B, WAIT_C: begin
                    busy <= 1;

                    if (cycle_count == 2) begin
                        do_protocol(selected_proto, latched_data, result);
                        data_out <= result;
                        done <= 1;
                        protocol_active <= selected_proto;

                        // ✅ Debug Info
                        $display("🧠 DEBUG: Time=%0t | State=%0d | Latched Proto=%b | Latched Data=%h | Result=%h",
                                 $time, current_state, selected_proto, latched_data, result);
                    end
                end
                default: begin
                    busy <= 0;
                    protocol_active <= PROTO_NONE;
                end
            endcase
        end
    end

    // Optional Assertion (Cycle check)
    always @(posedge clk) begin
        if (busy && done)
            assert (cycle_count == 2) else $error("❌ Timing violation: Done too early at %0t", $time);
    end

    // Debug Assignments
    always @(*) begin
        debug_cycle_count = cycle_count;
        debug_state = current_state;
    end

endmodule
Add design from EDA Playground
