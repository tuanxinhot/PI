const MachineState = require('./machine_state.js');
const _E_ = MachineState._EVENTS_;
const ScannerBase = require('./scanner_base.js');

class DummyScanner extends ScannerBase {
	constructor(dummyBarcodeList, interval) {
		super('Dummy scanner', '');
		this.data = dummyBarcodeList;
		this.dataPointer = 0;

		// Setup to emulate reading a barcode from a scanner at the given intervals
		// The same barcode will be sent until a call to next() is made
		this.timer = setInterval(() => this.read(this.data[this.dataPointer]), interval);
	}

    pulseOn() {
        // Do nothing
    }

    pulseOff() {
        // Do nothing
    }

	// Increments or resets the pointer of the current barcode to raise in the 'scanned' event
	next() {
		this.dataPointer++;
		if (this.dataPointer >= this.data.length) { this.dataPointer = 0 }
	}

	dispose() {
		clearInterval(this.timer);
	}

}

module.exports = DummyScanner;