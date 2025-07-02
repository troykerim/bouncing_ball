`timescale 1ns / 1ps
module top(
    input CLK_I,
    output VGA_HS_O,
    output VGA_VS_O,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B
);

// Clock Wizard module declaration
wire pxl_clk;
clk_wiz_0 clk_div_inst (
    .CLK_IN1(CLK_I),
    .CLK_OUT1(pxl_clk)
);

// VGA timing constants for 1920x1080 @ 60Hz
localparam FRAME_WIDTH  = 1920;
localparam FRAME_HEIGHT = 1080;
localparam H_FP  = 88;
localparam H_PW  = 44;
localparam H_MAX = 2200;
localparam V_FP  = 4;
localparam V_PW  = 5;
localparam V_MAX = 1125;
localparam H_POL = 1'b1;
localparam V_POL = 1'b1;

// Moving box constants
localparam BOX_WIDTH = 6;
localparam BOX_CLK_DIV = 1000000;
localparam BOX_X_MAX = FRAME_WIDTH - BOX_WIDTH;
localparam BOX_Y_MAX = FRAME_HEIGHT - BOX_WIDTH;
localparam BOX_X_MIN = 0;
localparam BOX_Y_MIN = 0;
localparam BOX_X_INIT = 12'h000;
localparam BOX_Y_INIT = 12'h400;

// Internal signals
reg [11:0] h_cntr_reg = 0;
reg [11:0] v_cntr_reg = 0;
reg h_sync_reg = ~H_POL;
reg v_sync_reg = ~V_POL;
reg h_sync_dly_reg = ~H_POL;
reg v_sync_dly_reg = ~V_POL;
reg [3:0] vga_red_reg = 0;
reg [3:0] vga_green_reg = 0;
reg [3:0] vga_blue_reg = 0;
reg [3:0] vga_red;
reg [3:0] vga_green;
reg [3:0] vga_blue;

reg [11:0] box_x_reg = BOX_X_INIT;
reg box_x_dir = 1;
reg [11:0] box_y_reg = BOX_Y_INIT;
reg box_y_dir = 1;
reg [24:0] box_cntr_reg = 0;

wire update_box;
wire pixel_in_box;
reg active;

assign update_box = (box_cntr_reg == (BOX_CLK_DIV - 1));
assign pixel_in_box = (h_cntr_reg >= box_x_reg && h_cntr_reg < (box_x_reg + BOX_WIDTH)) &&
                      (v_cntr_reg >= box_y_reg && v_cntr_reg < (box_y_reg + BOX_WIDTH));

// Box color logic
always @* begin
    if (pixel_in_box) begin
        vga_red   = 4'hF;
        vga_green = 4'hF;
        vga_blue  = 4'hF;
    end else begin
        vga_red   = 4'h0;
        vga_green = 4'h0;
        vga_blue  = 4'h0;
    end
end

// Box update
always @(posedge pxl_clk) begin
    if (update_box) begin
        box_x_reg <= (box_x_dir) ? box_x_reg + 1 : box_x_reg - 1;
        box_y_reg <= (box_y_dir) ? box_y_reg + 1 : box_y_reg - 1;

        if ((box_x_dir && box_x_reg >= BOX_X_MAX - 1) || (!box_x_dir && box_x_reg <= BOX_X_MIN + 1))
            box_x_dir <= ~box_x_dir;
        if ((box_y_dir && box_y_reg >= BOX_Y_MAX - 1) || (!box_y_dir && box_y_reg <= BOX_Y_MIN + 1))
            box_y_dir <= ~box_y_dir;
    end
end

// Box clock divider
always @(posedge pxl_clk) begin
    if (box_cntr_reg == (BOX_CLK_DIV - 1))
        box_cntr_reg <= 0;
    else
        box_cntr_reg <= box_cntr_reg + 1;
end

// Horizontal counter
always @(posedge pxl_clk) begin
    if (h_cntr_reg == H_MAX - 1)
        h_cntr_reg <= 0;
    else
        h_cntr_reg <= h_cntr_reg + 1;
end

// Vertical counter
always @(posedge pxl_clk) begin
    if (h_cntr_reg == H_MAX - 1) begin
        if (v_cntr_reg == V_MAX - 1)
            v_cntr_reg <= 0;
        else
            v_cntr_reg <= v_cntr_reg + 1;
    end
end

// Sync signal generation
always @(posedge pxl_clk) begin
    if (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1) && h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1))
        h_sync_reg <= H_POL;
    else
        h_sync_reg <= ~H_POL;

    if (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1) && v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1))
        v_sync_reg <= V_POL;
    else
        v_sync_reg <= ~V_POL;
end

// Active video region
always @(*) begin
    active = (h_cntr_reg < FRAME_WIDTH) && (v_cntr_reg < FRAME_HEIGHT);
end

// Delay sync and RGB signals
always @(posedge pxl_clk) begin
    v_sync_dly_reg <= v_sync_reg;
    h_sync_dly_reg <= h_sync_reg;
    vga_red_reg    <= vga_red;
    vga_green_reg  <= vga_green;
    vga_blue_reg   <= vga_blue;
end

// Output 
assign VGA_HS_O = h_sync_dly_reg;
assign VGA_VS_O = v_sync_dly_reg;
assign VGA_R = vga_red_reg;
assign VGA_G = vga_green_reg;
assign VGA_B = vga_blue_reg;

endmodule
