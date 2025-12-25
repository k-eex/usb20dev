//==============================================================================
// Testbench body for byte-parallel CRC test
//
// Compares byte-parallel device CRC modules against host reference CRC
// (usb_host_beh.step_crc5/step_crc16), similarly to verif/testbenches/crc/tb.sv.
//==============================================================================

`include "../testbenches/tb_header.svh"

//-----------------------------------------------------------------------------
// DUT top / reference host
//-----------------------------------------------------------------------------
usb_fe_if usb_fe();

logic [7:0]  dut_data   = '0;
logic        dut_valid  = 1'b0;
logic        dut_clear  = 1'b0;

logic [4:0]  dut_crc5;
logic        dut_crc5_valid;

logic [15:0] dut_crc16;
logic        dut_crc16_valid;

usb_crc5_byte dut5 (
    .clk     (tb_clk),
    .rst     (~tb_rst_n),
    .clear_i (dut_clear),
    .data_i  (dut_data),
    .valid_i (dut_valid),
    .crc_o   (dut_crc5),
    .valid_o (dut_crc5_valid)
);

usb_crc16_byte dut16 (
    .clk     (tb_clk),
    .rst     (~tb_rst_n),
    .clear_i (dut_clear),
    .data_i  (dut_data),
    .valid_i (dut_valid),
    .crc_o   (dut_crc16),
    .valid_o (dut_crc16_valid)
);

usb_host_beh host_beh (
    .phy (usb_fe.phy)
);

//`define STOP_TIME  100ms   // Time when test stops
`define TEST_DESCR "CRC byte-parallel test: compare CRC5 and CRC16 on Host and Device"
`define DATA_TOTAL 128

//-----------------------------------------------------------------------------
// Testbench body
//-----------------------------------------------------------------------------
logic [7:0]  data_in   [`DATA_TOTAL-1:0];

logic [4:0]  crc5_val;
logic [15:0] crc16_val;

logic [4:0]  crc5_host [`DATA_TOTAL-1:0];
logic [4:0]  crc5_dev  [`DATA_TOTAL-1:0];

logic [15:0] crc16_host [`DATA_TOTAL-1:0];
logic [15:0] crc16_dev  [`DATA_TOTAL-1:0];

task automatic device_step(input logic [7:0] b);
begin
    @(posedge tb_clk); #1ns;
    dut_data  = b;
    dut_valid = 1'b1;
    @(posedge tb_clk); #1ns;
    dut_valid = 1'b0;
end
endtask

initial
begin : tb_body
    tb_err = 0; // no errors

    // Reset
    wait(tb_rst_n);

    // Test start
    #100ns tb_busy = 1;

    // Random stimulus
    for (int i = 0; i < `DATA_TOTAL; i++) begin
        data_in[i] = $urandom();
    end

    // Clear/init CRCs
    @(posedge tb_clk); #1ns;
    dut_clear = 1'b1;
    @(posedge tb_clk); #1ns;
    dut_clear = 1'b0;

    // Host-side reference accumulation (same style as existing crc tb)
    $display("%0d, I: %m: Host calculate CRC5/CRC16", $time);
    for (int i = 0; i < `DATA_TOTAL; i++) begin
        #10ns host_beh.step_crc5 (data_in[i], crc5_val);
        #10ns host_beh.step_crc16(data_in[i], crc16_val);
        #1ns  crc5_host[i]  = host_beh.crc5;
        #1ns  crc16_host[i] = host_beh.crc16;
    end

    // Device-side accumulation
    $display("%0d, I: %m: Device calculate CRC5/CRC16 (byte-parallel)", $time);
    for (int i = 0; i < `DATA_TOTAL; i++) begin
        device_step(data_in[i]);

        // The DUT outputs are registered; valid_o should pulse corresponding to valid_i (pipelined by 1).
        // We sample after the step.
        @(posedge tb_clk); #1ns;
        crc5_dev[i]  = dut_crc5;
        crc16_dev[i] = dut_crc16;

        // Optional sanity: check valid pulses (not a strict requirement if you later change pipelining)
        if (!dut_crc5_valid)  $display("%0d, W: %m: crc5 valid not asserted at i=%0d",  $time, i);
        if (!dut_crc16_valid) $display("%0d, W: %m: crc16 valid not asserted at i=%0d", $time, i);
    end

    // Compare results
    $display("%0d, I: %m: Compare results", $time);
    for (int i = 0; i < `DATA_TOTAL; i++) begin
        if (crc5_dev[i] != crc5_host[i]) begin
            tb_err++;
            $display("%0d, E: %m: CRC5 mismatch at i=%0d: host=%0h dev=%0h data=%0h",
                     $time, i, crc5_host[i], crc5_dev[i], data_in[i]);
        end
        if (crc16_dev[i] != crc16_host[i]) begin
            tb_err++;
            $display("%0d, E: %m: CRC16 mismatch at i=%0d: host=%0h dev=%0h data=%0h",
                     $time, i, crc16_host[i], crc16_dev[i], data_in[i]);
        end
    end

    // Test end
    #3us tb_busy = 0;
end

`include "../testbenches/tb_footer.svh"