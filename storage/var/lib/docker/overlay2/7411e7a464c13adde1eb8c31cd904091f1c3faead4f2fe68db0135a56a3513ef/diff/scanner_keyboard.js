var LIL = require('linux-input-device');
const ScannerBase = require('./scanner_base.js');

class KeyboardScanner extends ScannerBase {

    constructor(device) {
        super(device, '');
        this.running = '';
        this.inputDevice = new LIL(device);
        this.inputDevice.on('state', (value, key, kind) => {
            if (value) {
                if (key == 28) {
                    this.read(this.running);
                    this.running = '';
                } else {
                    this.running += String.fromCharCode(key);
                }
            }
        });
    }

    pulseOn() {
        // Do nothing
    }

    pulseOff() {
        // Do nothing
    }
    
    dispose() {
        // add this to avoid "EBADF: bad file descriptor, close" error
        this.inputDevice.once('readable', () => {
            this.inputDevice.destroy();
        });
    }
}

module.exports = KeyboardScanner;