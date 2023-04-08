const HID = require('node-hid');
const ScannerBase = require('./scanner_base.js');

class UsbScanner extends ScannerBase  {
    constructor(path) {
        super(path, /[^\x20-\x7F]/g);
        const inputDevice = new HID.HID(path);

        inputDevice.on('data', data => {
            // Data received are in buffer, thus has to convert to string.
            this.read(data.toString());  
        });
    }

    pulseOn() {
        // Do nothing
    }

    pulseOff() {
        // Do nothing
    }

    dispose() {
        console.log('Closing scanner USB port...');
        this.inputDevice.close(err => {
            if (err) {
                console.log('Scanner USB port closed with error.');
                console.error(err);
                return;
            }
            console.log('Scanner USB port closed.');
        });
    }
}

module.exports = UsbScanner;