module multiplier(
    input [31:0] a,
    input [31:0] b,
    input is_signed,
    output [63:0] product
);
    wire [63:0] product_signed;
    wire [63:0] product_unsigned;
    
    assign product_signed = $signed(a) * $signed(b);
    assign product_unsigned = a * b;
    
    assign product = is_signed ? product_signed : product_unsigned;
endmodule
