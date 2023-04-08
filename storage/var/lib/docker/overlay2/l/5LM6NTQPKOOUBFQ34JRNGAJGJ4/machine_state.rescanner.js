'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2021 - Jabil Circuit Inc      ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

class Rescanner {
	#limit;
	#isStale = false;
	#timer;
	#isTriggerStop = false; // Additional property to tell outside world triggering is stopped.

	constructor(timeout, limit, getActiveScanner, trigger, getSerials) {
		this.#limit = limit;

		// Define the stop process
		const _stop_ = () => { if (this.#timer) { clearInterval(this.#timer); } };

		this.#timer = setInterval(() => {
			// If this rescanner is no longer the active one then stop triggering
			if (getActiveScanner() !== this) {
				_stop_();
				this.#isTriggerStop = true;
				return;
			}
			// Check whether the limit has been reached and any serial number returned from scanner
			if (this.#limit == 1 || getSerials()) {
				_stop_();
				this.#isTriggerStop = true;
				return;
			}
			// Trigger rescanning
			this.#isStale = true;
			trigger();
			this.#limit--;
		}, timeout);
	}

	isStale() { return this.#isStale; }

	isTriggerStop() { return this.#isTriggerStop; }
}

module.exports = Rescanner;