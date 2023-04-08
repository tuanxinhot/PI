'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2016-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Product Team

const EventEmitter = require('events');
const Rescanner = require('./machine_state.rescanner');

const _MODE_ = {
	_SCAN_: 'Scan',
	_NOSCAN_: 'noScan', // This value not properly capitalised so dependant apps and old code don't break, but it kills me inside =(
	_BYPASS_: 'Bypass',
	_ONTHEFLY_: 'ontheFly'
};

const _EVENTS_ = {
	_CHANGED_: 'changed',
	_MODE_: 'mode', 				// Gets thrown whenever the mode changes
	_BOARD_ON_: 'boardon',			// Gets thrown whenever a board becomes available
	_BOARD_OFF_: 'boardoff',		// Gets thrown whenever a board moves off during transfer
	_BOARD_OK_: 'boardok',			// Gets thrown when a board gets an OK for all plugins 			
	_BYPASS_BOARD_OK_: 'bpboardok', // Special event to turn off Baout during bypass mode
	_SERIAL_: 'serial',				// Gets thrown when a valid serial is set
	_BOARD_OUST_: 'boardoust',		// Gets thrown when a board is forcefully removed (i.e. non-transfer removal)
	_DOSCAN_: 'doscan',					// Gets thrown when scanners should scan
	_TRANSFERRING_: 'transferring', // Gets thrown at the start of a board transfer
	_STOPTRANSFER_: 'stoptransfer',
	_TRANSFERRED_: 'transferred'
}

const _SERIAL_STATUS_ = {
	_NA_: -1,
	_OK_: 0,
	_PREFIXNOT_: 1,
	_SUFFIXNOT_: 2
}

const _VAL_TRIGGER_ = {
	_BA_: 'BA',
	_MR_: 'MR'
}

class Barcode {
	Serial = undefined;
	LastScannedValue = undefined;
	LastScannedTime = Date.now();
	Status = _SERIAL_STATUS_._NA_;

	reset() {
		this.Serial = undefined;
		this.LastScannedValue = undefined;
		this.LastScannedTime = Date.now();
		this.Status = _SERIAL_STATUS_._NA_;
	}

	hold(barcode) {
		this.LastScannedValue = barcode;
		this.LastScannedTime = Date.now();
	}

	assign(serial) {
		this.Serial = serial;
		this.Status = _SERIAL_STATUS_._OK_;
		this.LastScannedTime = Date.now();
		this.LastScannedValue = undefined;
	}

	isInAssimilationWindow() {
		return this.LastScannedValue
			&& Date.now() - this.LastScannedTime < 500 // milliseconds
	}

	getTransient() {
		return { Serial: this.Serial, Status: this.Status, Last: this.LastScannedValue };
	}

}

// Helper class to handle conditional timeout
class TimeoutHandler {
    #_isRunning = false;
    #_isTimeout = false;
    #_isCancel = false;
    #_timeoutHandle;
    constructor() {}
    delay(miliseconds) {
        return new Promise((resolve, reject) => {
            setTimeout(() => resolve(), miliseconds);
        });
    }
    Cancel() {
        this.#_isCancel = true;
    }
    StartTimer(getCustomState, miliseconds) {
		return new Promise(async (resolve, reject) => {
			// Only one instance of promise can run at one time.
			if (!this.#_isRunning) {
				this.#_isRunning = true;
				this.#_isTimeout = false;
                this.#_isCancel = false;

				this.#_timeoutHandle = setTimeout(() => {
					if (miliseconds > 0) {
						this.#_isTimeout = true;
						this.#_isRunning = false;
						resolve(this.#_isTimeout);
					}
				}, miliseconds);

				while(!this.#_isCancel && !this.#_isTimeout && !getCustomState()) {
					await this.delay(10);
				}

				clearTimeout(this.#_timeoutHandle);
				this.#_isRunning = false;
                if (this.#_isCancel)
				    reject({ isCancel: this.#_isCancel, isRunning: this.#_isRunning });
                else
                    resolve(this.#_isTimeout);
			} else {
				reject({ isCancel: this.#_isCancel, isRunning: this.#_isRunning });
			}
		});
    }
}

// Validation process wrapped as a class to 
// keep code in MachineState class clean
class ValidationProcess {
    constructor() {}
    // Call from machine state
    begin(
		getMessageHandler,
        requireWaitMRin,
		isMode,
        getBAinState,
		getMRinState,
		turnOnBAout,
		setResumeScanFalse,
		getResumeScan,
        scannerTimeoutExitCondition, 
        isSerialValid, 
        isScannerDisposed, 
        serverTimeoutExitCondition,
        resetStates,
        getScannerTimeout,
        getServerTimeout
    ) {
		if (isMode(_MODE_._NOSCAN_)) {
			turnOnBAout();
			if (requireWaitMRin()) {
				this.waitForMRin(
					getMessageHandler,
					getBAinState,
					getMRinState,
					serverTimeoutExitCondition,
					resetStates,
					getServerTimeout
				);
			} else {
				this.waitForServerResponse(
					getMessageHandler,
					getBAinState,
					serverTimeoutExitCondition,
					resetStates,
					getServerTimeout
				);
			}
		} else {
			this.waitForScanner(
				getMessageHandler,
				requireWaitMRin,
				getBAinState,
				getMRinState,
				turnOnBAout,
				setResumeScanFalse,
				getResumeScan,
				scannerTimeoutExitCondition, 
				isSerialValid, 
				isScannerDisposed, 
				serverTimeoutExitCondition,
				resetStates,
				getScannerTimeout,
				getServerTimeout
			);
		}
    }
    // Wait for scanner. Not meant to call from outside.
    waitForScanner (
		getMessageHandler,
        requireWaitMRin,
        getBAinState,
		getMRinState,
		turnOnBAout,
		setResumeScanFalse,
		getResumeScan,
        scannerTimeoutExitCondition, 
        isSerialValid, 
        isScannerDisposed, 
        serverTimeoutExitCondition,
        resetStates,
        getScannerTimeout,
        getServerTimeout
    ) {
        console.log('Waiting for scanner to complete scan.');
        let scannerTimeoutHandler = new TimeoutHandler();
        scannerTimeoutHandler
            .StartTimer(() => scannerTimeoutExitCondition(), getScannerTimeout())
            .then((isScannerTimeout) => {
                if (!isScannerTimeout && isSerialValid()) {
					console.log('Acquired a valid serial number from scanner.');
					turnOnBAout();
                    if (requireWaitMRin()) {
                        this.waitForMRin(
							getMessageHandler,
                            getBAinState,
							getMRinState,
                            serverTimeoutExitCondition,
                            resetStates,
                            getServerTimeout
                        );
                    } else {
                        this.waitForServerResponse(
							getMessageHandler,
							getBAinState,
                            serverTimeoutExitCondition,
                            resetStates,
                            getServerTimeout
                        );
                    }
                } else {
					let message = '';
                    if (isScannerDisposed()) {
						message = 'STA: Scanner reset.';
                    } else {
						setResumeScanFalse();
						message = 'ERR: No response or no barcode returned from scanner!';
						getMessageHandler().postMessage(message);
						this.waitForUserTriggerRescan(
							getResumeScan,
							getBAinState,
							resetStates,
							getMessageHandler
						);
                    }
					console.log(message);
                }
            }).catch((res) => console.log(`Scanner timeout routine stopped unexpectedly. IsTaskCancel=${res.isCancel}, IsTaskRunning=${res.isRunning}.`));
    }
	// Wait for user interaction. Not meant to call from outside.
	waitForUserTriggerRescan(
		getResumeScan,
		getBAinState,
		resetStates,
		getMessageHandler
	) {
		console.log('Waiting for user to trigger rescan.');
		let resumeScanTimeoutHandler = new TimeoutHandler();
		resumeScanTimeoutHandler
			.StartTimer(() => { return (!getBAinState() || getResumeScan()); }, 0)
			.then(() => {
				if (!getBAinState()) {
					console.log('Board was removed. Skip user interaction.');
				} else {
					if (getResumeScan()) {
						console.log('User ask for rescan.');
						getMessageHandler().postMessage('STA: Rescanning', 5000);
						resetStates();
					}
				}
			}).catch((res) => console.log(`Resume scan timeout routine stopped unexpectedly. IsTaskCancel=${res.isCancel}, IsTaskRunning=${res.isRunning}.`))
	}
    // Wait for MRin, only run when MR validation turned on.
    waitForMRin(
		getMessageHandler,
        getBAinState,
		getMRinState,
        serverTimeoutExitCondition,
        resetStates,
        getServerTimeout
    ) {
        console.log('MR validation turned on. Waiting for MRin to turn on before proceed.');
        let mrInTimeoutHandler = new TimeoutHandler();
        mrInTimeoutHandler
            .StartTimer(() => { return (!getBAinState() || getMRinState()); }, 0)
            .then(() => {
                if (getBAinState() && getMRinState()) {
					console.log('MRin turned on. Proceed to next step.');
                    this.waitForServerResponse(
						getMessageHandler,
						getBAinState,
                        serverTimeoutExitCondition,
                        resetStates,
                        getServerTimeout
                    );
                } else if (!getBAinState() && !getMRinState()) {
                    console.log('BAin turned off, state resetted.')
                } else {
                    console.log(`Unexpected state detected while waiting for MRin turn on. BAin=${getBAinState()}, MRin=${getMRinState()}.`);
                }
            }).catch((res) => console.log(`MRin state timeout routine stopped unexpectedly. IsTaskCancel=${res.isCancel}, IsTaskRunning=${res.isRunning}.`))
    }
    // Method to execute wait server response. Not meant to call from outside.
    waitForServerResponse(
		getMessageHandler,
		getBAinState,
        serverTimeoutExitCondition,
        resetStates,
        getServerTimeout
    ) {
        console.log('Waiting for server to response.');
        let serverTimeoutHandler = new TimeoutHandler();
        serverTimeoutHandler
            .StartTimer(() => serverTimeoutExitCondition(), getServerTimeout())
            .then((isServerTimeout) => {
				if (!getBAinState()) return; // If BAin turn off while waiting for server response, return immediately

                if (isServerTimeout) {
					let message = 'WAR: Server timeout or board validation failed.';
                    console.log(message);
					getMessageHandler().postMessage(message, 5000);
                    resetStates();
                } else {
					console.log('Received server response. Proceed to next step.');
                }
            }).catch((res) => console.log(`Server timeout routine stopped unexpectedly. IsTaskCancel=${res.isCancel}, IsTaskRunning=${res.isRunning}.`));
    }
}

// Simple handler to keep message and auto clear
// message by specific time interval
class MessageHandler {
    #message;
    #messageClearHandler;
    constructor() {
        this.#message = '';
        this.#messageClearHandler = null;
    }
    getLastMessage() {
        return this.#message;
    }
    postMessage(message, timeoutMiliseconds = 0) {
		if (message.length <= 50) {
			this.#message = message;
		} else {
			this.#message = message.slice(0, 50);
		}
        if (this.#messageClearHandler) {
            this.#messageClearHandler.Cancel();
            this.#messageClearHandler = null;
        }
        this.#messageClearHandler = new TimeoutHandler();
        this.#messageClearHandler
        .StartTimer(() => { return !this.#messageClearHandler; }, timeoutMiliseconds)
        .then(() => this.#message = '')
        .catch((res) => { 
            if (!res.isCancel) console.log(`Unexpected state occurred while post new message. State=${res.isRunning}.`); 
        });
    }
}

class MachineState extends EventEmitter {

	//╭────────────────────────────────────────────────────────────────────────────────╮ 
	//│ To reduce the cognitive complexity of machine state timing, 					│
	//│ we need to decouple triggering the scanner and 									│
	//│ getting back a scan from the scanner.											│
	//│ 																				│
	//│ Triggering the scanner happens when:											│
	//│ 1) PICO is set to validate on BA												│
	//│ 	1.1) and BA is turned on													│
	//│ 2) PICO is set to validate on MR												│
	//│ 	2.1) and MR is turned on													│
	//│ 	2.2) and BA is turned on													│
	//│ Whether the scanner is in continuous scan mode or otherwise does not matter		│
	//│ as triggering should happen regardless.											│
	//│ 																				│
	//│ Getting a scan back from the scanner should be assumed to be random, i.e. 		│
	//│ 1) It could continuously happen because the scanner is in continuous scan mode	│
	//│ 2) The scanner was triggered to start scanning based on the above triggering	│
	//│ 																				│
	//│ Therefore, in code:																│
	//│ 1) The 'boardon' event is fired to trigger a scanner							│
	//│ 2) SetSerial() needs to have the appropriate validity checks 					│
	//│ 	since it will be called at random						 					│
	//│ 3) The 'serial' event is fired when a valid serial is accepted					│
	//│ 									🖖											│
	//╰────────────────────────────────────────────────────────────────────────────────╯ 

	constructor() {
		super();
		this._top = new Barcode();
		this._bottom = new Barcode();
		this._state = {
			Mode: _MODE_._SCAN_,			// Denotes what scan mode the unit is in
			DownstreamReady: false,			// Denotes if the downstream machine is ready to accept a board (i.e. MR IN in Cogiscan)
			UpstreamBoardAvailable: false,	// Denotes if there is a board available to go into the downstream machine (i.e. BA IN in Cogiscan)
			UpstreamBoardOK: false,			// Denotes if there is a board that is validated and ready to go into the downstream machine (i.e. BA OUT in Cogiscan)
			Transfer: false					// Denotes if the conveyor is in the process of transferring the board to the downstream machine
		};
		this._config = {
			BarcodePrefix: '',
			BarcodeSuffix: '',
			ValidationTrigger: _VAL_TRIGGER_._BA_,
			RescanTimeout: 12000, // milliseconds. Follows CogiScan default
			RescanLimit: 2, // Follows CogiScan default
			TriggerTime: 3 // seconds. Follows CogiScan default
		};
		this._rescanner = null;
		this._isSerialValid = false; // Additional property to set to true when a valid serial number returned from scanner.
		this._resumeScan = true; // Additional property to set to false when scanner time out or no response.
		this._validateProcessHandler = null; // Place holder to hold validation process as an object
		this._messageHandler = new MessageHandler(); // Place holder to hold mesage handler as an object
		this._runtimeModeChanged = false;
	}

	isMode(mode) {
		return this._state.Mode == mode;
	}

	isTriggeredBy(triggerType) {
		return this._config.ValidationTrigger == triggerType;
	}

	/**
	 * Resets the state except for downstream-ready.
	 * Downstream-ready is not reset and should only ever be set by the read from the GPIO.
	 */
	reset() {
		this._state.UpstreamBoardAvailable = false;
		this._state.UpstreamBoardOK = false;
		this._state.DownstreamReady = false;
		this._state.Transfer = false;
		this._top.reset();
		this._bottom.reset();
		this._rescanner = null;
		this._isSerialValid = false;
		this._validateProcessHandler = null;
		this._runtimeModeChanged = false;
	}

	/**
	 * Resets the state and emits a 'transferred' event.
	 */
	completeTransfer() {
		// Emit the 'transferred' event
		this.emit(_EVENTS_._TRANSFERRED_, this.getState(), this.getSerials(), this._runtimeModeChanged);
		/* Reset has to be happen after the trasnsferred event is emited so that
			the serial number is not empty when '#!TRANSFER' + serial msg is sent to MES*/
		this.reset();
	}

	setSerial(target, serial) {
		// On bypass and no-scan modes we discard the serial number
		if (this.isMode(_MODE_._BYPASS_) || this.isMode(_MODE_._NOSCAN_)) {
			target.reset();
			return false;
		}

		// If the serials are the same then just ignore
		if (target.Serial == serial) {
			return false;
		}

		// If SerialStatus is okay, then ignore, do checking for new scans only
		if (target.Status == _SERIAL_STATUS_._OK_ && !(this._rescanner && this._rescanner.isStale())) {
			target.hold(serial);
			return false;
		}

		if (this._config.BarcodePrefix
		&& !serial.startsWith(this._config.BarcodePrefix)) {
			console.log(`Scanned barcode ${serial} does not match prefix ${this._config.BarcodePrefix}`);
			target.Serial = undefined;
			target.Status = _SERIAL_STATUS_._PREFIXNOT_;
			target.hold(serial);
			return false;
		}

		if (this._config.BarcodeSuffix
		&& !serial.endsWith(this._config.BarcodeSuffix)) {
			console.log(`Scanned barcode ${serial} does not match prefix ${this._config.BarcodePrefix}`);
			target.Serial = undefined;
			target.Status = _SERIAL_STATUS_._SUFFIXNOT_;
			target.hold(serial);
			return false;
		}

		if (this._state.UpstreamBoardAvailable || this.isMode(_MODE_._ONTHEFLY_)) {
			target.assign(serial);
			this.emit(_EVENTS_._SERIAL_, this.getState(), this.getSerials());
			this._isSerialValid = true;
			return true;
		}

		// Store last scanned value and time for later comparison in changeState()
		target.hold(serial);
		return false;
	}

	setSerialTop(serial) {
		return this.setSerial(this._top, serial);
	}

	setSerialBottom(serial) {
		return this.setSerial(this._bottom, serial);
	}

	getSerials() {
		return {
			Top: this._top.Serial,
			TopTime: this._top.Serial ? this._top.LastScannedTime : undefined,
			Bottom: this._bottom.Serial,
			BottomTime: this._bottom.Serial ? this._bottom.LastScannedTime : undefined,
		};
	}

	hasSerials() {
		return this._top.Status === _SERIAL_STATUS_._OK_ || this._bottom.Status === _SERIAL_STATUS_._OK_;
	}

	getBarcodes() {
		return { Top: this._top.getTransient(), Bottom: this._bottom.getTransient() };
	}

	getLastMessage() {
		return this._messageHandler.getLastMessage(); // Expose last message to /state api
	}

	getResumeTest() {
		return this._resumeScan;
	}

	setResumeTestTrue() {
		this._resumeScan = true;
	}

	// Copy the state object so someone else can see it, without being able to modify the state
	getState() {
		return JSON.parse(JSON.stringify(this._state));
	}

	// Copy the config state object so someone else can see it, without being able to modify the them
	getConfig() {
		return JSON.parse(JSON.stringify(this._config));
	}

	changePrefixSuffix(prefix, suffix) {
		this._config.BarcodePrefix = prefix;
		this._config.BarcodeSuffix = suffix;
	}

	changeValidationTrigger(validationTrigger) {
		this._config.ValidationTrigger = validationTrigger;
	}

	changeRescan(timeoutInSecs, limit) {
		this._config.RescanTimeout = timeoutInSecs * 1000;
		this._config.RescanLimit = limit;
		if (timeoutInSecs == 0) {
			this._rescanner = null;
		}
	}

	changeTriggerTime(triggertime) {
		this._config.TriggerTime = triggertime;
	}

	/** This is a private call and should not be called externally */
	_assimilateOrTriggerScan() {
		if (this.isMode(_MODE_._NOSCAN_) || this.isMode(_MODE_._BYPASS_)) {
			if (this.isMode(_MODE_._NOSCAN_) && !this._validateProcessHandler) {
				this._validateProcessHandler = new ValidationProcess();
			}
			return;
		}
		// Check if there is already a valid serial number
		// On very rare occasions when a board becomes available under continuous
		// scanning, the barcode is scanned just moments before the board triggers 
		// the 'board available' sensor on the conveyor
		// In such cases we check back if there was a scan <0.5sec earlier and use that as
		// the serial number if there is
		let has_assimilation = false;
		if (!this._top.Serial && this._top.isInAssimilationWindow()) {
			console.log(`Assimilating top barcode ${this._top.LastScannedValue}.`);
			this.setSerialTop(this._top.LastScannedValue);
			has_assimilation = true;
		}
		if (!this._bottom.Serial && this._bottom.isInAssimilationWindow()) {
			console.log(`Assimilating bottom barcode ${this._bottom.LastScannedValue}.`);
			this.setSerialBottom(this._bottom.LastScannedValue);
			has_assimilation = true;
		}
		// Set up rescanning if it is not already set up
		if (!this._rescanner) {
			this._rescanner = new Rescanner(this._config.RescanTimeout, this._config.RescanLimit,
				() => this._rescanner,
				() => this._assimilateOrTriggerScan(),
				() => { return this._isSerialValid; });
		}
		// Set up a validation process handler
		if (!this._validateProcessHandler) this._validateProcessHandler = new ValidationProcess();
		if (!has_assimilation) {
			this._isSerialValid = false;
			this.emit(_EVENTS_._DOSCAN_, this._config.TriggerTime * 1000);
		}
	}

	// Update a state item with a new value.
	changeState(item, value) {
		let newValue = value;
		// All values except for the mode is a boolean value, so we cast it for safety
		if (item !== 'Mode') {
			newValue = Boolean(newValue);
		}

		const oldValue = this._state[item];
		// If the value didn't change then just exit
		if (oldValue === newValue) {
			return;
		}

		// Declare the helper lambda that emits events
		const _emit_ = event => this.emit(event, this.getState(), this.getSerials());
		// Save the new value to state
		this._state[item] = newValue;

		switch (item) { // Don't forget to keep the most often triggered cases at the top

			case 'UpstreamBoardAvailable':
				if (newValue) {
					// A board became available
					_emit_(_EVENTS_._BOARD_ON_);
					this._assimilateOrTriggerScan();

					// Start validation process under Scan and on the fly mode, 
					// while BAin=true and board not transferring.
					if (!this.isMode(_MODE_._BYPASS_) && !this._state.Transfer && this._state.UpstreamBoardAvailable) {
						this._validateProcessHandler.begin(
							() => { return this._messageHandler; },
							() => { return this.isTriggeredBy(_VAL_TRIGGER_._MR_); },
							(mode) => { return this.isMode(mode); },
							() => { return this._state.UpstreamBoardAvailable; },
							() => { return this._state.DownstreamReady; },
							() => { _emit_(_EVENTS_._BOARD_OK_); },
							() => { this._resumeScan = false; },
							() => { return this._resumeScan; },
							() => { return (this._isSerialValid || (this._rescanner ? this._rescanner.isTriggerStop() : true)); },
							() => { return this._isSerialValid; },
							() => { return !this._rescanner; },
							() => { return (!this._state.UpstreamBoardAvailable || this._state.UpstreamBoardOK); },
							() => { this.reset(); _emit_(_EVENTS_._BOARD_OUST_); this._resumeScan = true; },
							() => { return (this._config.RescanTimeout * this._config.RescanLimit); },
							() => { return 20000; }
						);
					}

					if (this.isMode(_MODE_._BYPASS_) && this._state.UpstreamBoardAvailable && this._state.Transfer) {
						_emit_(_EVENTS_._BYPASS_BOARD_OK_);
					}
				} else if (this._state.Transfer) {
					if (!this._state.UpstreamBoardAvailable && !this._state.DownstreamReady) {
						this.completeTransfer();
						return;
					} else {
						if (this.isMode(_MODE_._BYPASS_) && !this._state.UpstreamBoardAvailable) {
							// This is the fix for bypass mode where it should turn off BAout
							// when BAin is turned off. However emitting _EVENTS_._BOARD_OFF_ 
							// event not able to turn off BAout for some reason, emitting
							// _EVENTS_._BOARD_OUST_ turn off the BAout successfully.
							_emit_(_EVENTS_._BOARD_OUST_);
						} else {
							// Board has left the conveyor's IR sensor
							_emit_(_EVENTS_._BOARD_OFF_);
						}
					}
				} else {
					// If we are not transferring then likely someone physically removed the board OR
					// when extra long board not yet finish transfering 
					// Check for the log messege to double confirm the extra long board case,
					// i.e., check for 'DS:0' before '>>> #!TRANSFER' shows up
					console.log('Board manually removed. Resetting.');
					this.reset();
					_emit_(_EVENTS_._BOARD_OUST_);
					this._messageHandler.postMessage('STA: Board manually removed. Resetting.', 5000);
					this._resumeScan = true;
				}
				return;

			case 'UpstreamBoardOK':
				if (newValue) {
					this._rescanner = null;
					if (this.isMode(_MODE_._BYPASS_)) _emit_(_EVENTS_._BOARD_OK_);
					return;
				}
				break;

			case 'DownstreamReady':
				// Added additional condition to listening to BA before complete transfer.
				if (!newValue && !this._state.UpstreamBoardAvailable && this._state.Transfer) {
					// If transferring and downstream stops being ready then set the transfer as completed
					this.completeTransfer();
					return;
				} else {
					if (this._state.Transfer) {
						if (!this._state.DownstreamReady) {
							_emit_(_EVENTS_._STOPTRANSFER_);
						} else if (this._state.DownstreamReady) {
							_emit_(_EVENTS_._TRANSFERRING_);
						}
						return;
					}
				}
				break;

			case 'Transfer':
				if (newValue) {
					// Trigger to start the transfer
					_emit_(_EVENTS_._TRANSFERRING_);
					return;
				}
				break;

			case 'Mode':
				if (!Object.values(_MODE_).includes(newValue)) {
					this._state[item] = oldValue;
					throw new RangeError(`'${newValue}' is not accepted as a valid Mode. Did you make a typo.`);
				} else {
					if (!this._state.Transfer) {
						console.log(`Mode changed from "${oldValue}" to "${this._state[item]}". Resetting.`);
						this.reset(); 
						_emit_(_EVENTS_._BOARD_OUST_); 
						this._resumeScan = true;
					} else {
						console.log(`Mode changed from "${oldValue}" to "${this._state[item]}" while transferring.`);
						// Only set _runtimeModeChanged to true when mode changed from SCAN/ONTHEFLY/NOSCAN to BYPASS
						// or BYPASS to SCAN/ONTHEFLY/NOSCAN
						if ((oldValue == _MODE_._SCAN_ || oldValue == _MODE_._ONTHEFLY_ || oldValue == _MODE_._NOSCAN_) && this.isMode(_MODE_._BYPASS_)) {
							console.log(`Preserve #!TRANSFER due to previous mode was "${oldValue}".`);
							this._runtimeModeChanged = true;
						} else if (oldValue == _MODE_._BYPASS_ && (this.isMode(_MODE_._SCAN_) || this.isMode(_MODE_._ONTHEFLY_) || this.isMode(_MODE_._NOSCAN_))) {
							console.log(`Skip send #!TRANSFER due to previous mode was "${oldValue}".`);
							this._runtimeModeChanged = true;
						}
					}
				}
				_emit_(_EVENTS_._MODE_);
				return;

			default:
				// The property name given is invalid, remove it and throw an exception
				delete this._state[item];
				throw new RangeError(`State does not have property '${item}'. Did you make a typo.`);
		}

		// This event mainly gets emitted when certain states become false
		_emit_(_EVENTS_._CHANGED_);

	}

}

module.exports = {
	State: MachineState,
	_MODE_: _MODE_,
	_EVENTS_: _EVENTS_,
	_VAL_TRIGGER_: _VAL_TRIGGER_
};
