//==============================================================================
// Byte-parallel USB CRC5 with registered I/O.
//
// USB CRC5 polynomial: x^5 + x^2 + 1 (0b00101)
// USB bit order: LSB-first on the wire.
//
// IMPORTANT:
// - USB token CRC5 is defined over 11 bits (ADDR[6:0] + ENDP[3:0]) LSB-first.
// - This module updates CRC over a byte-stream. For tokens, you should feed
//   exactly those 11 bits (packed into bytes) and ignore the CRC field bits.
//==============================================================================

module usb_crc5_byte (
    input  logic       clk,
    input  logic       rst,

    input  logic       clear_i,   // init CRC to 0x1F
    input  logic [7:0] data_i,
    input  logic       valid_i,

    output logic [4:0] crc_o,
    output logic       valid_o
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

    logic [4:0] crc_q, crc_d;

    function automatic [4:0] crc5_usb_byte_next (
        input [4:0] crc_in,
        input [7:0] data
    );
        integer k;
        reg [4:0] c;
        reg       mix;
        begin
            c = crc_in;
            for (k = 0; k < 8; k = k + 1) begin
                mix = c[4] ^ data[k];
                c   = {c[3:0], 1'b0};
                if (mix) begin
                    // taps at x^2 and x^0 for poly x^5 + x^2 + 1
                    c[2] = c[2] ^ 1'b1;
                    c[0] = c[0] ^ 1'b1;
                end
            end
            crc5_usb_byte_next = c;
        end
    endfunction

    always_comb begin
        crc_d = crc_q;

        if (clear_r) begin
            crc_d = 5'h1F;
        end else if (valid_r) begin
            crc_d = crc5_usb_byte_next(crc_q, data_r);
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            crc_q   <= 5'h1F;
            crc_o   <= 5'h1F;
            valid_o <= 1'b0;
        end else begin
            crc_q   <= crc_d;
            crc_o   <= crc_d;
            valid_o <= valid_r;
        end
    end

endmodule