module fifo_2_depth #(
    parameter WIDTH = 8
) (
    input  logic             clk_i,
    input  logic             rst_i,

    input  logic             up_valid,
    output logic             up_ready,
    input  logic [WIDTH-1:0] up_data,

    output logic             down_valid,
    input  logic             down_ready,
    output logic [WIDTH-1:0] down_data
);

    logic             push;
    logic             pop;
    logic             empty;
    logic             full;
    logic             wr_ptr;
    logic             rd_ptr;

    logic [WIDTH-1:0] mem [2];

    assign empty      = wr_ptr ^  rd_ptr;
    assign full       = wr_ptr ~^ rd_ptr;

    assign up_ready   = ~full;
    assign down_valid = ~empty;

    assign push       = up_valid && ~full_o;
    assign pop        = down_ready && ~empty_o;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            wr_ptr <= 1'b0;
        end else if (push) begin
            wr_ptr <= ~wr_ptr;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            rd_ptr <= 1'b0;
        end else if (pop) begin
            rd_ptr <= ~rd_ptr;
        end
    end

    always_ff @(posedge clk_i) begin
        if (push) begin
            mem[wr_ptr] <= up_data;
        end
    end

    assign down_data = mem[rd_ptr];

endmodule
