// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


// Setup
// ---------------------------------------------------------------------

// Test Hardware
//  - Imp005 Breakout Board
//  - Brother QL-720NW label printer

// Software Dependencies
//  - QL720NW Driver Class

// Driver for printer
class QL720NW {
    static VERSION = "0.1.0";

    _uart = null; // A preconfigured UART
    _buffer = null; // buffer for building text

    // Commands
    static CMD_ESCP_ENABLE = "\x1B\x69\x61\x00";
    static CMD_ESCP_INIT = "\x1B\x40";

    static CMD_SET_ORIENTATION = "\x1B\x69\x4C"
    static CMD_SET_TB_MARGINS = "\x1B\x28\x63\x34\x30";
    static CMD_SET_LEFT_MARGIN = "\x1B\x6C";
    static CMD_SET_RIGHT_MARGIN = "\x1B\x51";

    static CMD_ITALIC_START = "\x1b\x34";
    static CMD_ITALIC_STOP = "\x1B\x35";
    static CMD_BOLD_START = "\x1b\x45";
    static CMD_BOLD_STOP = "\x1B\x46";
    static CMD_UNDERLINE_START = "\x1B\x2D\x31";
    static CMD_UNDERLINE_STOP = "\x1B\x2D\x30";

    static CMD_SET_FONT_SIZE = "\x1B\x58\x00";
    static CMD_SET_FONT = "\x1B\x6B";

    static CMD_BARCODE = "\x1B\x69"
    static CMD_2D_BARCODE = "\x1B\x69\x71"

    static LANDSCAPE = "\x31";
    static PORTRAIT = "\x30";

    // Special characters
    static TEXT_NEWLINE = "\x0A";
    static PAGE_FEED = "\x0C";

    // Font Parameters
    static ITALIC = 1;
    static BOLD = 2;
    static UNDERLINE = 4;

    static FONT_SIZE_24 = 24;
    static FONT_SIZE_32 = 32;
    static FONT_SIZE_48 = 48;

    static FONT_BROUGHAM = 0;
    static FONT_LETTER_GOTHIC_BOLD = 1;
    static FONT_BRUSSELS = 2;
    static FONT_HELSINKI = 3;
    static FONT_SAN_DIEGO = 4;

    // Barcode Parameters
    static BARCODE_CODE39 = "t0";
    static BARCODE_ITF = "t1";
    static BARCODE_EAN_8_13 = "t5";
    static BARCODE_UPC_A = "t5";
    static BARCODE_UPC_E = "t6";
    static BARCODE_CODABAR = "t9";
    static BARCODE_CODE128 = "ta";
    static BARCODE_GS1_128 = "tb";
    static BARCODE_RSS = "tc";
    static BARCODE_CODE93 = "td";
    static BARCODE_POSTNET = "te";
    static BARCODE_UPC_EXTENTION = "tf";

    static BARCODE_CHARS = "r1";
    static BARCODE_NO_CHARS = "r0";

    static BARCODE_WIDTH_XXS = "w4";
    static BARCODE_WIDTH_XS = "w0";
    static BARCODE_WIDTH_S = "w1";
    static BARCODE_WIDTH_M = "w2";
    static BARCODE_WIDTH_L = "w3";

    static BARCODE_RATIO_2_1 = "z0";
    static BARCODE_RATIO_25_1 = "z1";
    static BARCODE_RATIO_3_1 = "z2";

    // 2D Barcode Parameters
    static BARCODE_2D_CELL_SIZE_3 = "\x03";
    static BARCODE_2D_CELL_SIZE_4 = "\x04";
    static BARCODE_2D_CELL_SIZE_5 = "\x05";
    static BARCODE_2D_CELL_SIZE_6 = "\x06";
    static BARCODE_2D_CELL_SIZE_8 = "\x08";
    static BARCODE_2D_CELL_SIZE_10 = "\x0A";

    static BARCODE_2D_SYMBOL_MODEL_1 = "\x01";
    static BARCODE_2D_SYMBOL_MODEL_2 = "\x02";
    static BARCODE_2D_SYMBOL_MICRO_QR = "\x03";

    static BARCODE_2D_STRUCTURE_NOT_PARTITIONED = "\x00";
    static BARCODE_2D_STRUCTURE_PARTITIONED = "\x01";

    static BARCODE_2D_ERROR_CORRECTION_HIGH_DENSITY = "\x01";
    static BARCODE_2D_ERROR_CORRECTION_STANDARD = "\x02";
    static BARCODE_2D_ERROR_CORRECTION_HIGH_RELIABILITY = "\x03";
    static BARCODE_2D_ERROR_CORRECTION_ULTRA_HIGH_RELIABILITY = "\x04";

    static BARCODE_2D_DATA_INPUT_AUTO = "\x00";
    static BARCODE_2D_DATA_INPUT_MANUAL = "\x01";

    constructor(uart, init = true) {
        _uart = uart;
        _buffer = blob();

        if (init) return initialize();
    }

    function initialize() {
        _uart.write(CMD_ESCP_ENABLE); // Select ESC/P mode
        _uart.write(CMD_ESCP_INIT); // Initialize ESC/P mode

        return this;
    }


    // Formating commands
    function setOrientation(orientation) {
        // Create a new buffer that we prepend all of this information to
        local orientationBuffer = blob();

        // Set the orientation
        orientationBuffer.writestring(CMD_SET_ORIENTATION);
        orientationBuffer.writestring(orientation);

        _uart.write(orientationBuffer);

        return this;
    }

    function setRightMargin(column) {
        return _setMargin(CMD_SET_RIGHT_MARGIN, column);
    }

    function setLeftMargin(column) {
        return _setMargin(CMD_SET_LEFT_MARGIN, column);;
    }

    function setFont(font) {
        if (font < 0 || font > 4) throw "Unknown font";

        _buffer.writestring(CMD_SET_FONT);
        _buffer.writen(font, 'b');

        return this;
    }

    function setFontSize(size) {
        if (size != 24 && size != 32 && size != 48) throw "Invalid font size";

        _buffer.writestring(CMD_SET_FONT_SIZE)
        _buffer.writen(size, 'b');
        _buffer.writen(0, 'b');

        return this;
    }

    // Text commands
    function write(text, options = 0) {
        local beforeText = "";
        local afterText = "";

        if (options & ITALIC) {
            beforeText += CMD_ITALIC_START;
            afterText += CMD_ITALIC_STOP;
        }

        if (options & BOLD) {
            beforeText += CMD_BOLD_START;
            afterText += CMD_BOLD_STOP;
        }

        if (options & UNDERLINE) {
            beforeText += CMD_UNDERLINE_START;
            afterText += CMD_UNDERLINE_STOP;
        }

        _buffer.writestring(beforeText + text + afterText);

        return this;
    }

    function writen(text, options = 0) {
        return write(text + TEXT_NEWLINE, options);
    }

    function newline() {
        return write(TEXT_NEWLINE);
    }

    // Barcode commands
    function writeBarcode(data, config = {}) {
        // Set defaults
        if (!("type" in config)) { config.type <- BARCODE_CODE39; }
        if (!("charsBelowBarcode" in config)) { config.charsBelowBarcode <- true; }
        if (!("width" in config)) { config.width <- BARCODE_WIDTH_XS; }
        if (!("height" in config)) { config.height <- 0.5; }
        if (!("ratio" in config)) { config.ratio <- BARCODE_RATIO_2_1; }

        // Start the barcode
        _buffer.writestring(CMD_BARCODE);

        // Set the type
        _buffer.writestring(config.type);

        // Set the text option
        if (config.charsBelowBarcode) {
            _buffer.writestring(BARCODE_CHARS);
        } else {
            _buffer.writestring(BARCODE_NO_CHARS);
        }

        // Set the width
        _buffer.writestring(config.width);

        // Convert height to dots
        local h = (config.height * 300).tointeger();
        // Set the height
        _buffer.writestring("h"); // Height marker
        _buffer.writen(h & 0xFF, 'b'); // Lower bit of height
        _buffer.writen((h / 256) & 0xFF, 'b'); // Upper bit of height

        // Set the ratio of thick to thin bars
        _buffer.writestring(config.ratio);

        // Set data
        _buffer.writestring("\x62");
        _buffer.writestring(data);

        // End the barcode
        if (config.type == BARCODE_CODE128 || config.type == BARCODE_GS1_128 || config.type == BARCODE_CODE93) {
            _buffer.writestring("\x5C\x5C\x5C");
        } else {
            _buffer.writestring("\x5C");
        }

        return this;
    }

    function write2dBarcode(data, config = {}) {
        // Set defaults
        if (!("cell_size" in config)) { config.cell_size <- BARCODE_2D_CELL_SIZE_3; }
        if (!("symbol_type" in config)) { config.symbol_type <- BARCODE_2D_SYMBOL_MODEL_2; }
        if (!("structured_append_partitioned" in config)) { config.structured_append_partitioned <- false; }
        if (!("code_number" in config)) { config.code_number <- 0; }
        if (!("num_partitions" in config)) { config.num_partitions <- 0; }

        if (!("parity_data" in config)) { config["parity_data"] <- 0; }
        if (!("error_correction" in config)) { config["error_correction"] <- BARCODE_2D_ERROR_CORRECTION_STANDARD; }
        if (!("data_input_method" in config)) { config["data_input_method"] <- BARCODE_2D_DATA_INPUT_AUTO; }

        // Check ranges
        if (config.structured_append_partitioned) {
            config.structured_append <- BARCODE_2D_STRUCTURE_PARTITIONED;
            if (config.code_number < 1 || config.code_number > 16) throw "Unknown code number";
            if (config.num_partitions < 2 || config.num_partitions > 16) throw "Unknown number of partitions";
        } else {
            config.structured_append <- BARCODE_2D_STRUCTURE_NOT_PARTITIONED;
            config.code_number = "\x00";
            config.num_partitions = "\x00";
            config.parity_data = "\x00";
        }

        // Start the barcode
        _buffer.writestring(CMD_2D_BARCODE);

        // Set the parameters
        _buffer.writestring(config.cell_size);
        _buffer.writestring(config.symbol_type);
        _buffer.writestring(config.structured_append);
        _buffer.writestring(config.code_number);
        _buffer.writestring(config.num_partitions);
        _buffer.writestring(config.parity_data);
        _buffer.writestring(config.error_correction);
        _buffer.writestring(config.data_input_method);

        // Write data
        _buffer.writestring(data);

        // End the barcode
        _buffer.writestring("\x5C\x5C\x5C");

        return this;
    }

    // Prints the label
    function print() {
        _buffer.writestring(PAGE_FEED);
        _uart.write(_buffer);
        _buffer = blob();
    }

    function _setMargin(command, margin) {
        local marginBuffer = blob();
        marginBuffer.writestring(command);
        marginBuffer.writen(margin & 0xFF, 'b');

        _uart.write(marginBuffer);

        return this;
    }

    function _typeof() {
        return "QL720NW";
    }
}

// Tests
// ---------------------------------------------------------------------

class QL720NWUartUsbDriverTestCase extends ImpTestCase {
    // UART on imp005
    uart = null;
    dataString = "";
    usbHost = null;
    loadPin = null;
    _device = null;
    getInfo = "/x1B/x69/x53";

    function setUp() {
        return "Hi from #{__FILE__}!";
    }


    // Test connection of valid device instantiated driver
    function test1_UartOverUsbConnection() {


        // Request user to connect the correct device to imp
        this.info("Connect any Uart over Usb device to imp");

        return Promise(function(resolve, reject) {
            usbHost = USB.Host(hardware.usb);
            usbHost.registerDriver(QL720NWUartUsbDriver, QL720NWUartUsbDriver.getIdentifiers());
            // Register cb for connection event
            usbHost.on("connected", function(device) {

                // Check the device is an instance of QL720NWUartUsbDriver
                if (typeof device == "QL720NWUartUsbDriver") {

                    // Store the driver for the next test
                    _device = device;

                    return resolve("Device was a Uart over Usb device");
                }

                // Wrong device was connected
                reject("Device connected is not a Uart over Usb device");
            }.bindenv(this));
        }.bindenv(this))
    }


    // Tests the driver is compatible with a uart device
    function test2_UartPrinterDriver() {
        return Promise(function(resolve, reject) {

            // Check there is a valid device driver
            if (_device != null) {

                local printer = QL720NW(_device);

                local testString = "I'm a Blob\n";
                local dataString = "";

                printer
                    .setOrientation(QL720NW.LANDSCAPE)
                    .setFont(QL720NW.FONT_SAN_DIEGO)
                    .setFontSize(QL720NW.FONT_SIZE_48)
                    .write("San Diego 48 ")
                    .print();

                // Requires manual validation
                resolve("Printed data")


            } else {
                reject("No device connected");
            }
        }.bindenv(this))
    }


    // Tests the driver is compatible with a uart device
    function test3_On() {
        return Promise(function(resolve, reject) {

            local getInfoReq = blob(3);

            // Get printer info
            getInfoReq.writen(0x1B, 'b');
            getInfoReq.writen(0x69, 'b');
            getInfoReq.writen(0x53, 'b');

            // Check there is a valid device driver
            if (_device != null) {

                local printer = QL720NW(_device);

                _device.on("data", function(data) {
                    this.info(data);
                    resolve();
                }.bindenv(this));

                _device.write(getInfoReq);

            } else {
                reject("No device connected");
            }
        }.bindenv(this))
    }

    // Tests that an event handler can be unsubscribed from an event
    function test4_Off() {

        return Promise(function(resolve, reject) {

            // Check there is a valid device driver
            if (_device != null) {

                _device.on("data", function(data) {
                    this.info(data);
                    resolve();
                }.bindenv(this));

                // Assert there are no event listeners registered
                assertEqual(1, _device._eventHandlers.len());

                _device.off("data");

                // Assert there are no event listeners registered
                assertEqual(0, _device._eventHandlers.len());

                resolve();

            } else {
                reject("No device connected");
            }

        }.bindenv(this))
    }


    function tearDown() {
        return "#{__FILE__} Test finished";
    }
}
