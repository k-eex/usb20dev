//==============================================================================
// Interface to USB frontend using external USB FS transceiver (TUSB1106)
//
// Keeps the same ctrl modport expected by usb_sie.sv:
//   dp_rx, dn_rx inputs to SIE
//   dp_tx, dn_tx, tx_oen outputs from SIE
//   pu pullup control
//
// Replaces the tri-state "analog" frontend with a TUSB1106 digital interface.
//==============================================================================

interface usb_fe_if ();

    // Signals consumed/produced by usb_sie (unchanged)
    logic dp_rx;     // USB Data+ input  (sampled line state)
    logic dn_rx;     // USB Data- input  (sampled line state)
    logic dp_tx;     // USB Data+ output (drive request)
    logic dn_tx;     // USB Data- output (drive request)
    logic tx_oen;    // output enable for driving
    logic pu;        // pull-up connect control

    // Existing ctrl modport (unchanged)
    modport ctrl (
        input  dp_rx,
        input  dn_rx,
        output dp_tx,
        output dn_tx,
        output tx_oen,
        output pu
    );

    // -------------------------------------------------------------------------
    // TUSB1106-facing pins (new "phy" side)
    // -------------------------------------------------------------------------
    // Receive sense from transceiver
    logic VP;        // transceiver sense (maps to D+ state)
    logic VM;        // transceiver sense (maps to D- state)

    // Drive control to transceiver
    logic VPO;       // transceiver drive out (maps to D+)
    logic VMO;       // transceiver drive out (maps to D-)
    logic OE_n;      // transceiver output enable, active low

    // Other control pins
    logic SOFTCON;   // pull-up connect control (maps from pu)
    logic SPEED;     // 1 = FS
    logic SUSPEND;   // optional; 0 for normal

    // Present a "phy" modport for top-level wiring
    modport phy (
        input  VP,
        input  VM,
        output VPO,
        output VMO,
        output OE_n,
        output SOFTCON,
        output SPEED,
        output SUSPEND
    );

    // -------------------------------------------------------------------------
    // Internal mapping between SIE signals and transceiver pins
    // -------------------------------------------------------------------------

    // RX mapping: just forward sensed line state (J/K/SE0 become VP/VM)
    // J: VP=1, VM=0; K: VP=0, VM=1; SE0: VP=0, VM=0
    assign dp_rx = VP;
    assign dn_rx = VM;

    // Pull-up connect/disconnect
    assign SOFTCON = pu;

    // Fixed configuration for now
    assign SPEED   = 1'b1; // full-speed
    assign SUSPEND = 1'b0; // normal operation

    // Drive enable: usb20dev uses tx_oen=1 to drive, TUSB1106 uses OE_n=0 to drive
    assign OE_n = ~tx_oen;

    // Drive mapping:
    //  - SE0: dp_tx=0 dn_tx=0 => VPO=0 VMO=0
    //  - J:   dp_tx=1 dn_tx=0 => VPO=1 VMO=0
    //  - K:   dp_tx=0 dn_tx=1 => VPO=0 VMO=1
    //  - illegal dp_tx=1 dn_tx=1 => force SE0
    always_comb begin
        VPO = 1'b0;
        VMO = 1'b0;

        if (tx_oen) begin
            unique case ({dp_tx, dn_tx})
                2'b00: begin VPO = 1'b0; VMO = 1'b0; end // SE0
                2'b10: begin VPO = 1'b1; VMO = 1'b0; end // J
                2'b01: begin VPO = 1'b0; VMO = 1'b1; end // K
                default: begin VPO = 1'b0; VMO = 1'b0; end // avoid illegal
            endcase
        end
    end

endinterface : usb_fe_if
