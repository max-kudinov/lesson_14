module sram_singleport #(
    parameter WIDTH  = 8,
    parameter DEPTH  = 8,
    parameter ADDR_W = $clog2(DEPTH)
) (
    input  logic              clk_i,
    input  logic              wen_i,
    input  logic              ren_i,
    input  logic [ADDR_W-1:0] addr_i,
    input  logic [ WIDTH-1:0] data_i,
    output logic [ WIDTH-1:0] data_o
);

    logic [WIDTH-1:0] sram [DEPTH];

    always_ff @(posedge clk_i) begin
        if (wen_i) begin
            sram[addr_i] <= data_i;
        end else if (ren_i) begin
            data_o       <= sram[addr_i];
        end
    end

endmodule
