module fifo_singleport #(
    parameter WIDTH  = 8,
    parameter DEPTH  = 8
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

    localparam N_BANKS    = 2;
    localparam BUF_DEPTH  = 2;

    localparam CNT_MAX    = DEPTH;
    localparam CNT_W      = $clog2(CNT_MAX + 1);

    localparam BANK_DEPTH = DEPTH / 2;
    localparam PTR_W      = $clog2(BANK_DEPTH);
    localparam PTR_MAX    = PTR_W'(BANK_DEPTH - 1);
    localparam BANK_CNT_W = $clog2(BANK_DEPTH + 1);

    // ------------------------------------------------------------------------
    // Local signals
    // ------------------------------------------------------------------------

    // FIFO control
    logic                  push;
    logic                  pop;

    // SRAM
    logic [  PTR_W-1:0]    wr_ptr        [N_BANKS];
    logic [  PTR_W-1:0]    rd_ptr        [N_BANKS];

    logic [  PTR_W-1:0]    addr          [N_BANKS];
    logic [N_BANKS-1:0]    wen;
    logic [N_BANKS-1:0]    ren;
    logic [  WIDTH-1:0]    sram_out      [N_BANKS];

    logic [N_BANKS-1:0]    sram_out_vld;
    logic [N_BANKS-1:0]    bypass;
    logic [N_BANKS-1:0]    sram_empty;

    // Buffers
    logic [  WIDTH-1:0]    buf_in        [N_BANKS];
    logic [  WIDTH-1:0]    buf_out       [N_BANKS];
    logic [N_BANKS-1:0]    buf_wr_en;
    logic [N_BANKS-1:0]    buf_rd_en;
    logic [N_BANKS-1:0]    buf_full;
    logic [N_BANKS-1:0]    buf_almost_full;

    logic                  wr_bank_select;
    logic                  rd_bank_select;
    logic                  wr_selected;
    logic                  rd_selected;
    logic                  buf_ready;
    logic [N_BANKS-1:0]    direct_write;

    logic [     CNT_W-1:0] elem_cnt;
    logic [     CNT_W-1:0] elem_cnt_next;
    logic [BANK_CNT_W-1:0] bank_cnt      [N_BANKS];
    logic [BANK_CNT_W-1:0] bank_cnt_next [N_BANKS];

    // ------------------------------------------------------------------------
    // SRAM banks
    // ------------------------------------------------------------------------

    // Number of memory banks is hardcoded in this implementation
    generate
        for (genvar i = 0; i < 2; i++) begin : sram_and_buf_gen

            sram_singleport #(
                .WIDTH ( WIDTH      ),
                .DEPTH ( BANK_DEPTH )
            ) i_bank (
                .clk_i  ( clk_i         ),
                .wen_i  ( wen       [i] ),
                .ren_i  ( ren       [i] ),
                .addr_i ( addr      [i] ),
                .data_i ( data_i        ),
                .data_o ( sram_out  [i] )
            );

            fifo_dff #(
                .WIDTH ( WIDTH     ),
                .DEPTH ( BUF_DEPTH )
            ) i_buf (
                .clk_i         ( clk_i                ),
                .rst_i         ( rst_i                ),
                .wr_en_i       ( buf_wr_en        [i] ),
                .rd_en_i       ( buf_rd_en        [i] ),
                .data_i        ( buf_in           [i] ),
                .data_o        ( buf_out          [i] ),
                .full_o        ( buf_full         [i] ),
                .almost_full_o ( buf_almost_full  [i] ),
                // verilator lint_off PINCONNECTEMPTY
                .empty_o       (                      )
                // verilator lint_on PINCONNECTEMPTY
            );

        end
    endgenerate

    // ------------------------------------------------------------------------
    // Bank management logic
    // ------------------------------------------------------------------------

    always_comb begin
        for (int i = 0; i < 2; i++) begin

            // Intermediate variables
            wr_selected      = wr_bank_select == 1'(i);
            rd_selected      = rd_bank_select == 1'(i);
            buf_ready        = !buf_full[i] && !(sram_out_vld[i] && buf_almost_full[i]);

            bypass       [i] = sram_empty[i] && buf_ready;
            direct_write [i] = bypass[i] && push && wr_selected;

            wen          [i] = push && !bypass[i] && wr_selected;
            ren          [i] = !sram_empty[i] && buf_ready && !(push && wr_selected);
            addr         [i] = wen[i] ? wr_ptr[i] : rd_ptr[i];

            buf_wr_en    [i] = direct_write[i] || sram_out_vld[i];
            buf_rd_en    [i] = pop && rd_selected;
            buf_in       [i] = bypass[i] ? data_i : sram_out[i];
        end

        data_o = rd_bank_select ? buf_out[1] : buf_out[0];
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            wr_bank_select <= 1'b0;
            rd_bank_select <= 1'b0;
        end else begin
            if (push) wr_bank_select <= !wr_bank_select;
            if (pop ) rd_bank_select <= !rd_bank_select;
        end
    end

    always_comb begin
        for (int i = 0; i < 2; i++) begin
            bank_cnt_next[i] = bank_cnt[i];

            if (wen[i] && !ren[i]) begin
                bank_cnt_next[i] = bank_cnt[i] + 1'b1;
            end else if (ren[i] && !wen[i]) begin
                bank_cnt_next[i] = bank_cnt[i] - 1'b1;
            end
        end
    end

    always_ff @(posedge clk_i) begin
        for (int i = 0; i < 2; i++) begin
            if (rst_i) begin
                bank_cnt[i] <= '0;
            end else begin
                bank_cnt[i] <= bank_cnt_next[i];
            end
        end
    end

    always_ff @(posedge clk_i) begin
        for (int i = 0; i < 2; i++) begin
            if (rst_i) begin
                sram_empty[i] <= '1;
            end else begin
                sram_empty[i] <= bank_cnt_next[i] == '0;
            end
        end
    end

    always_ff @(posedge clk_i) begin
        for (int i = 0; i < 2; i++) begin
            if (rst_i) begin
                sram_out_vld[i] <= 1'b0;
            end else begin
                sram_out_vld[i] <= ren[i];
            end
        end
    end

    // ------------------------------------------------------------------------
    // Main FIFO logic
    // ------------------------------------------------------------------------

    assign push = wr_en_i;
    assign pop  = rd_en_i;

    always_ff @(posedge clk_i) begin
        for (int i = 0; i < 2; i++) begin
            if (rst_i) begin
                wr_ptr[i] <= PTR_W'(0);
            end else if (wen[i]) begin
                if (wr_ptr[i] == PTR_MAX) begin
                    wr_ptr[i] <= PTR_W'(0);
                end else begin
                    wr_ptr[i] <= wr_ptr[i] + 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk_i) begin
        for (int i = 0; i < 2; i++) begin
            if (rst_i) begin
                rd_ptr[i] <= PTR_W'(0);
            end else if (ren[i]) begin
                if (rd_ptr[i] == PTR_MAX) begin
                    rd_ptr[i] <= PTR_W'(0);
                end else begin
                    rd_ptr[i] <= rd_ptr[i] + 1'b1;
                end
            end
        end
    end

    always_comb begin
        elem_cnt_next = elem_cnt;

        if (push && !pop) begin
            elem_cnt_next = elem_cnt + 1'b1;
        end else if (pop && !push) begin
            elem_cnt_next = elem_cnt - 1'b1;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            elem_cnt <= '0;
        end else begin
            elem_cnt <= elem_cnt_next;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            empty_o <= '1;
            full_o  <= '0;
        end else begin
            empty_o <= elem_cnt_next == '0;
            full_o  <= elem_cnt_next == DEPTH;
        end
    end

endmodule
