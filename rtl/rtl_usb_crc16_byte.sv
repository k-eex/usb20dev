//==============================================================================
// Byte-parallel USB CRC16 (Data CRC) with registered I/O.
//
// USB CRC16 polynomial: x^16 + x^15 + x^2 + 1  (0x8005)
// USB bit order: LSB-first on the wire.
//
// Interface model:
//  - On valid_i, consumes data_i (one byte) and updates crc.
//  - clear_i initializes CRC to 0xFFFF (USB default).
//  - Outputs are registered: crc_o updates when valid_o is asserted.
//
// NOTE: This module computes the running CRC over the bitstream represented
// by consecutive bytes, interpreted LSB-first within each byte.
//==============================================================================

module usb_crc16_byte (
    input  logic        clk,
    input  logic        rst,

    input  logic        clear_i,   // init CRC to 0xFFFF
    input  logic [7:0]  data_i,
    input  logic        valid_i,

    output logic [15:0] crc_o,
    output logic        valid_o
);

    // Registered input
    logic [7:0] data_r;
    logic       valid_r;
    logic       clear_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_r  <= '0;
            valid_r <= 1'b0;
            clear_r <= 1'b0;
        end else begin
            data_r  <= data_i;
            valid_r <= valid_i;
            clear_r <= clear_i;
        end
    end

    // Internal CRC state
    logic [15:0] crc_q, crc_d;

    // One-byte LSB-first update (8 bit-steps unrolled by synthesis)
    function automatic [15:0] crc16_usb_byte_next (
        input [15:0] crc_in,
        input [7:0]  data
    );
        integer k;
        reg [15:0] c;
        reg        mix;
        begin
            c = crc_in;
            // LSB-first: process bit 0 first
            for (k = 0; k < 8; k = k + 1) begin
                mix = c[15] ^ data[k];
                // Shift left
                c = {c[14:0], 1'b0};
                if (mix) begin
                    // Apply taps for poly x^16 + x^15 + x^2 + 1 (0x8005)
                    c[15] = c[15] ^ 1'b1;
                    c[2]  = c[2]  ^ 1'b1;
                    c[0]  = c[0]  ^ 1'b1;
                end
            end
            crc16_usb_byte_next = c;
        end
    endfunction

    always_comb begin
        crc_d = crc_q;

        if (clear_r) begin
            crc_d = 16'hFFFF;
        end else if (valid_r) begin
            crc_d = crc16_usb_byte_next(crc_q, data_r);
        end
    end

    // Registered state + outputs
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            crc_q   <= 16'hFFFF;
            crc_o   <= 16'hFFFF;
            valid_o <= 1'b0;
        end else begin
            crc_q   <= crc_d;
            crc_o   <= crc_d;
            valid_o <= valid_r;
        end
    end

endmodule