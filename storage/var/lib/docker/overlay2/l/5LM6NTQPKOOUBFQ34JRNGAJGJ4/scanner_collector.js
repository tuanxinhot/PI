'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2016-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team
const DummyScanner = require('./scanner_dummy.js');
const EventEmitter = require('events');
const { setTimeout, clearTimeout } = require('timers');

class ScannerCollector extends EventEmitter {
	#activePulse = null;

	constructor() {
		super();
		this.scanners = [];
	}

	// Adds a scanner to this collector. Not thread-safe.
	add(scanner) {
		const _SCANNED_ = 'scanned';
		// Declare the lambda that will re-raise the 'scanned' event whenever a scanner fires a scan
		// We explicitly declare it so that we can remove it later if the scanner is removed
		const scan_handler = data => this.emit(_SCANNED_, data);
		scanner.on(_SCANNED_, scan_handler);
		// Add the scanner to the list of scanners
		this.scanners.push({
			device: scanner,
			// This lambda will be called when the scanner is removed from the array
			stop: () => {
				scanner.removeListener(_SCANNED_, scan_handler)
				// Close scanner serial port
				scanner.dispose();
			}
		})
		console.log(scanner.constructor.name, 'added to the scanner collector.')
	}

	// Removes a scanner from this collector. Not thread-safe.
	remove(scanner) {
		// Find the index of the scanner if it is in the array
		for (let index = 0, found = false; !found && index < this.scanners.length; index++) {
			if (this.scanners[index].device === scanner) {
				// Stop listening to the event
				this.scanners[index].stop();
				// Remove the scanner
				this.scanners.splice(index, 1);
				// Set the found flag
				found = true;
				console.log(scanner.constructor.name, 'removed from the scanner collector.')
			}
		}
	}

	removeAll() {
		while (this.scanners.length > 0) {
			this.scanners.pop().stop();
		}
	}

	addDummy(state) {
		// Create a new dummy scanner and add it to the list of scanners
		const debug_fake_barcode_samples = ["JAE1", "JAE2", "QW1", "QW2", "ABC1"];
		const dummy_scanner = new DummyScanner(debug_fake_barcode_samples, 2000);
		// Everytime a transfer is complete then we use the next dummy barcode
		state.on(_E_._TRANSFERRED_, () => dummy_scanner.next());
		console.log('DummyScanner of', debug_fake_barcode_samples, 'created.');
		this.add(dummy_scanner);
	}

	removeDummy() {
		const dummies = this.scanners.map(s => s.device).filter(s => s instanceof DummyScanner);
		dummies.forEach(s => {
			this.remove(s);
		});
	}

	trigger(duration) {
		if (this.#activePulse) { clearTimeout(this.#activePulse); }
		this.scanners.forEach(s => { s.device.pulseOn(); });
		const pulse = setTimeout(() => {if (this.#activePulse === pulse) { this.untrigger(); }}, duration);
		this.#activePulse = pulse;
	}

	untrigger() {
		this.#activePulse = null;
		this.scanners.forEach(s => { s.device.pulseOff(); })
	}

	count() {
		return this.scanners.length;
	}

}

module.exports = ScannerCollector;