module fifo_dualport #(
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

    // SRAM
    logic             ren;
    logic             wen;
    logic [WIDTH-1:0] sram_out;

    // Pointers
    logic [W_PTR-1:0] wr_ptr;
    logic [W_PTR-1:0] rd_ptr;
    logic             wr_circle_odd;
    logic             rd_circle_odd;

    // Prefetch and bypass
    logic             enable_bypass;
    logic             bypass_valid;
    logic [WIDTH-1:0] bypass_data;
    logic             almost_empty;
    logic [W_PTR-1:0] prefetch_ptr;

    // ------------------------------------------------------------------------
    // SRAM
    // ------------------------------------------------------------------------

    // Don't read from memory when almost empty, because the last element
    // has been already prefetched and its value is present on output
    assign ren = pop && ~almost_empty;
    // Don't write to memory when we write to the bypass register
    assign wen = push && ~enable_bypass;

    sram_dualport #(
        .WIDTH ( WIDTH ),
        .DEPTH ( DEPTH )
    ) i_mem (
        .clk_i   ( clk_i        ),
        .wen_i   ( wen          ),
        .ren_i   ( ren          ),
        .waddr_i ( wr_ptr       ),
        .raddr_i ( prefetch_ptr ),
        .data_i  ( data_i       ),
        .data_o  ( sram_out     )
    );

    // ------------------------------------------------------------------------
    // Prefetch and bypass logic
    // ------------------------------------------------------------------------

    // Fetch next element on read, that way it would appear on output before
    // read enable signal (show-ahead)
    assign prefetch_ptr = (rd_ptr == MAX_PTR) ? W_PTR'(0) : W_PTR'(rd_ptr + 1'b1);
    assign almost_empty = wr_ptr == prefetch_ptr;

    // Write to bypass register if the FIFO is empty or it has only 1 element
    // (almost empty) and we do push and pop simultaneously (basically
    // swapping the value in register)
    assign enable_bypass = push && (empty_o || (almost_empty && pop));

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            bypass_valid <= 1'b0;
        end else if (enable_bypass) begin
            bypass_valid <= 1'b1;
        end else if (pop) begin
            bypass_valid <= 1'b0;
        end
    end

    always_ff @(posedge clk_i) begin
        if (enable_bypass) begin
            bypass_data <= data_i;
        end
    end

    // ------------------------------------------------------------------------
    // Main FIFO logic
    // ------------------------------------------------------------------------

    assign push    = wr_en_i;
    assign pop     = rd_en_i;

    assign empty_o = (wr_ptr == rd_ptr) && (wr_circle_odd == rd_circle_odd);
    assign full_o  = (wr_ptr == rd_ptr) && (wr_circle_odd != rd_circle_odd);

    // Hide memory latency by choosing between SRAM and register
    assign data_o  = bypass_valid ? bypass_data : sram_out;

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
