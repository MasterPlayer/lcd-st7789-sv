`timescale 1ns / 1ps




module top (
    input  logic       GCLK_100MHz,
    output logic [7:0] LED        ,
    output logic       LCD_BLK    ,
    output logic       LCD_RST    ,
    output logic       LCD_DC     ,
    output logic       LCD_SDA    ,
    output logic       LCD_SCK    
);


    localparam integer TIMER_LIMIT = 5000000;

    logic clk100  ;
    logic reset100;
    logic clk50   ;

    logic [$clog2(TIMER_LIMIT)-1:0] timer        = '{default:0};

    logic [7:0] m_axis_tdata ;
    logic       m_axis_tkeep ;
    logic       m_axis_tuser ;
    logic       m_axis_tvalid;
    logic       m_axis_tlast ;
    logic       m_axis_tready;


    logic [7:0] component_r;
    logic [7:0] component_g;
    logic [7:0] component_b;

    logic       run      ;
    logic [7:0] operation;


    clk_wiz_100 clk_wiz_100_inst (
        .clk_in1 (GCLK_100MHz),
        .clk_out1(clk100     ), // output clk_out1
        .clk_out2(clk50      )  // output clk_out1
    );

    always_comb begin 
        LED = led_register;
    end 

    vio_reset vio_reset_inst (
        .clk       (clk100     ), // input wire clk
        .probe_out0(reset100   ), // output wire [0 : 0] probe_out0
        .probe_out1(run        ), // output wire [0 : 0] probe_out1
        .probe_out2(component_r), // output wire [7 : 0] probe_out2
        .probe_out3(component_g), // output wire [7 : 0] probe_out2
        .probe_out4(component_b)  // output wire [7 : 0] probe_out2
    );

    st7789_mgr st7789_mgr_inst (
        .CLK          (clk100       ),
        .RESET        (reset100     ),
        .RUN          (run          ),
        
        .COMPONENT_R  (component_r  ),
        .COMPONENT_G  (component_g  ),
        .COMPONENT_B  (component_b  ),
        
        .M_AXIS_TDATA (m_axis_tdata ),
        .M_AXIS_TKEEP (m_axis_tkeep ),
        .M_AXIS_TUSER (m_axis_tuser ),
        .M_AXIS_TVALID(m_axis_tvalid),
        .M_AXIS_TLAST (m_axis_tlast ),
        .M_AXIS_TREADY(m_axis_tready)
    );

    st7789_driver st7789_driver_inst (
        .CLK          (clk100       ),
        .RESET        (reset100     ),
        .SCLK         (clk50        ),
        .S_AXIS_TDATA (m_axis_tdata ),
        .S_AXIS_TKEEP (m_axis_tkeep ),
        .S_AXIS_TUSER (m_axis_tuser ),
        .S_AXIS_TVALID(m_axis_tvalid),
        .S_AXIS_TLAST (m_axis_tlast ),
        .S_AXIS_TREADY(m_axis_tready),
        .LCD_BLK      (LCD_BLK      ),
        .LCD_RST      (LCD_RST      ),
        .LCD_DC       (LCD_DC       ),
        .LCD_SDA      (LCD_SDA      ),
        .LCD_SCK      (LCD_SCK      )
    );



endmodule
