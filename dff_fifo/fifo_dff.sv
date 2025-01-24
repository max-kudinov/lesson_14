module fifo_dff #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
) (
    input  logic             clk_i,
    input  logic             rst_i,
    input  logic             wr_en_i,
    input  logic             rd_en_i,
    input  logic [WIDTH-1:0] data_i,
    output logic [WIDTH-1:0] data_o,
    output logic             empty_o,
    output logic             full_o
);

    // ------------------------------------------------------------------------
    // Local parameters
    // ------------------------------------------------------------------------

    localparam W_PTR   = $clog2(DEPTH);
    localparam MAX_PTR = W_PTR'(DEPTH - 1);

    // ------------------------------------------------------------------------
    // Local signals
    // ------------------------------------------------------------------------

    // FIFO control
    logic             push;
    logic             pop;

    // Pointers
    logic [W_PTR-1:0] wr_ptr;
    logic [W_PTR-1:0] rd_ptr;
    logic             wr_circle_odd;
    logic             rd_circle_odd;

    logic [WIDTH-1:0] mem [DEPTH];

    // ------------------------------------------------------------------------
    // Main FIFO logic
    // ------------------------------------------------------------------------

    assign push    = wr_en_i && (~full_o || rd_en_i);
    assign pop     = rd_en_i && ~empty_o;

    assign empty_o = (wr_ptr == rd_ptr) && (wr_circle_odd == rd_circle_odd);
    assign full_o  = (wr_ptr == rd_ptr) && (wr_circle_odd != rd_circle_odd);

    assign data_o  = mem[rd_ptr];

    always_ff @(posedge clk_i) begin
        if (push) begin
            mem[wr_ptr] <= data_i;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            wr_ptr        <= W_PTR'(0);
            wr_circle_odd <= 1'b0;
        end else if (push) begin
            if (wr_ptr == MAX_PTR) begin
                wr_ptr        <= W_PTR'(0);
                wr_circle_odd <= ~wr_circle_odd;
            end else begin
                wr_ptr <= wr_ptr + 1'b1;
            end
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            rd_ptr        <= W_PTR'(0);
            rd_circle_odd <= 1'b0;
        end else if (pop) begin
            if (rd_ptr == MAX_PTR) begin
                rd_ptr        <= W_PTR'(0);
                rd_circle_odd <= ~rd_circle_odd;
            end else begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

endmodule
