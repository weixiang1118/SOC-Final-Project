module uart_bram(
    // Wishbone Slave ports
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire wbs_stb_i,
    input wire wbs_cyc_i,
    input wire wbs_we_i,
    input wire [3:0] wbs_sel_i,
    input wire [31:0] wbs_dat_i,
    input wire [31:0] wbs_adr_i,
    output wire wbs_ack_o,
    output wire [31:0] wbs_dat_o,

    input wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb,
    
    output wire [2:0] irq
);

wire axi_ack_o, bram_ack_o;
wire [31:0] axi_dat_o, bram_dat_o;

// decode 
reg [1:0] decode; // 2'b00 = invalid, 2'b01 = AXI, 2'b10 = exmem
always@(*)begin
    if(wbs_adr_i[31:8] == 32'h3000_00) begin
    	decode[0] = wbs_stb_i && wbs_cyc_i;
    	decode[1] = 0;
    end
    else if(wbs_adr_i[31:8] == 32'h3800_00) begin
    	decode[0] = 0;
    	decode[1] = wbs_stb_i && wbs_cyc_i;
    end
    else decode = 2'b00;
end

assign wbs_ack_o = (decode == 2'b01) ? axi_ack_o : (decode == 2'b10) ? bram_ack_o : 0;
assign wbs_dat_o = (decode == 2'b01) ? axi_dat_o : (decode == 2'b10) ? bram_dat_o : 0;

uart uart(
    .wb_clk_i       (wb_clk_i   ),
    .wb_rst_i       (wb_rst_i   ),
    .wb_valid       (decode[0]  ),              
    .wbs_we_i       (wbs_we_i   ),              
    .wbs_sel_i      (wbs_sel_i  ),              
    .wbs_dat_i      (wbs_dat_i  ),              
    .wbs_adr_i      (wbs_adr_i  ),              
    .wbs_ack_o      (axi_ack_o  ),              
    .wbs_dat_o      (axi_dat_o  ),
    .io_in          (io_in      ),
    .io_out         (io_out     ),
    .io_oeb         (io_oeb     ),
    .user_irq       (irq        )
);

wb_bram wbbram(
    .wb_clk_i       (wb_clk_i   ),
    .wb_rst_i       (wb_rst_i   ),
    .wb_valid       (decode[1]  ),              
    .wbs_we_i       (wbs_we_i   ),              
    .wbs_sel_i      (wbs_sel_i  ),              
    .wbs_dat_i      (wbs_dat_i  ),              
    .wbs_adr_i      (wbs_adr_i  ),              
    .wbs_ack_o      (bram_ack_o ),              
    .wbs_dat_o      (bram_dat_o )                 
);
endmodule
