module sram_dualport #(
    parameter WIDTH  = 8,
    parameter DEPTH  = 8,
    parameter ADDR_W = $clog2(DEPTH)
) (
    input  logic              clk_i,
    input  logic              wen_i,
    input  logic              ren_i,
    input  logic [ADDR_W-1:0] waddr_i,
    input  logic [ADDR_W-1:0] raddr_i,
    input  logic [ WIDTH-1:0]  data_i,
    output logic [ WIDTH-1:0]  data_o
);

    logic [WIDTH-1:0] sram [DEPTH];

    always_ff @(posedge clk_i) begin
        if (wen_i) begin
            sram[waddr_i] <= data_i;
        end
    end

    always_ff @(posedge clk_i) begin
        if (ren_i) begin
            data_o <= sram[raddr_i];
        end
    end

endmodule
