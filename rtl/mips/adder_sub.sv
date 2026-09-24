module adder_sub #(
    parameter int WIDTH = 32
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             is_signed, // 1: Signed, 0: Unsigned
    input  logic             is_sub,    // 1: Subtraction (a - b), 0: Addition (a + b)
    output logic [WIDTH:0]   sum
);

    // Extended versions of inputs (WIDTH+1 bits)
    logic [WIDTH:0] ext_a;
    logic [WIDTH:0] ext_b;

    // Output of the XOR gates for B input conditional inversion
    logic [WIDTH:0] xor_b;

    always_comb begin
        // 1. Extension block (Multiplexers)
        if (is_signed) begin
            ext_a = {a[WIDTH-1], a}; // Sign extension
            ext_b = {b[WIDTH-1], b}; // Sign extension
        end else begin
            ext_a = {1'b0, a};       // Zero extension
            ext_b = {1'b0, b};       // Zero extension
        end

        // 2. XOR Gates: Conditionally invert b if it is subtraction (1's complement)
        // If is_sub = 0: xor_b = ext_b ^ 0 = ext_b
        // If is_sub = 1: xor_b = ext_b ^ 1 = ~ext_b
        xor_b = ext_b ^ {(WIDTH+1){is_sub}};

        // 3. Single Adder Core:
        // When is_sub = 0: sum = ext_a + ext_b + 0  (Normal Addition)
        // When is_sub = 1: sum = ext_a + ~ext_b + 1 (2's Complement Subtraction: A - B = A + ~B + 1)
        sum = ext_a + xor_b + is_sub;
    end

endmodule
