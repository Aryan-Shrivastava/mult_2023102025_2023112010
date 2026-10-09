`timescale 1ns / 1ps

// Exhaustive, self-checking testbench for mult_array.
// Applies all 256 (a, b) pairs, waits the 2-cycle latency, and compares p with a * b.
// Also checks that p does not change at the first clock edge, so a design with
// a shorter latency fails even if its products are correct.
module tb_mult;

    localparam CLK_PERIOD = 10;     // ns
    localparam LATENCY    = 2;      // clock cycles from input to registered product

    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;

    reg  [7:0] expected;
    reg  [7:0] p_before;            // p just before the new inputs are captured
    reg  [7:0] p_edge1;             // p half a cycle after edge 1
    time       t_edge1;
    reg        latency_ok;
    reg        product_ok;
    integer    i, j;
    integer    vectors;
    integer    errors;

    mult_array dut (
        .clk   (clk),
        .rst_n (rst_n),
        .a     (a),
        .b     (b),
        .p     (p)
    );

    // 10 ns clock
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Waveform
    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
    end

    initial begin
        vectors = 0;
        errors  = 0;
        a       = 4'd0;
        b       = 4'd0;

        // Hold reset low for the first 2 clock cycles (0-20 ns)
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                // Change inputs on the falling edge, away from the rising edge that samples them
                @(negedge clk);
                a        = i[3:0];
                b        = j[3:0];
                expected = i[3:0] * j[3:0];   // * is allowed in the testbench only
                p_before = p;

                // Edge 1 captures a and b into the input registers; p must not change yet
                @(posedge clk);
                @(negedge clk);
                p_edge1    = p;
                t_edge1    = $time;
                latency_ok = (p_edge1 === p_before);

                // Edge 2 (LATENCY = 2) captures the product into p; compare half a cycle later
                repeat (LATENCY - 1) @(posedge clk);
                @(negedge clk);
                product_ok = (p === expected);

                vectors = vectors + 1;
                if (!latency_ok)
                    $display("LATENCY: a=%0d b=%0d p changed from %0d to %0d after only 1 clock edge (t=%0d ns)",
                             a, b, p_before, p_edge1, t_edge1);
                if (!product_ok)
                    $display("MISMATCH: a=%0d b=%0d expected p=%0d got p=%0d (t=%0d ns)",
                             a, b, expected, p, $time);
                if (!latency_ok || !product_ok)
                    errors = errors + 1;    // count each failing vector once
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, %0d errors", vectors, errors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", vectors, errors);

        $finish;
    end

endmodule
