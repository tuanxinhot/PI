'use strict';
// ╓─────────────────────────────────────────╖
// ║ Copyright 2019-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const ScannerCollector = require('./scanner_collector.js');
const PlugInCollector = require('./plugin_collector.js');
const MachineState = require('./machine_state.js');
const InputOutput = require('./io_controller.js');
const _MODE_ = MachineState._MODE_;
const _E_ = MachineState._EVENTS_;
const _VT_ = MachineState._VAL_TRIGGER_;

class Flow {

	constructor(index) {
		this.index = index;

		this.state = new MachineState.State();

		// Hook up updating the state everytime there is a barcode scan
		this.scannersTop = new ScannerCollector();
		this.scannersTop.on('scanned', serial => this.state.setSerialTop(serial));
		this.scannersBottom = new ScannerCollector();
		this.scannersBottom.on('scanned', serial => this.state.setSerialBottom(serial));

		this.plugins = new PlugInCollector({ flowindex: index });

		// Declare the helper lambda used for printing out the given state
		const _print_state_ = (state, serials) => {
			let msg = 'F:' + this.index
				+ '  |  BA:' + ~~state.UpstreamBoardAvailable
				+ '  |  DS:' + ~~state.DownstreamReady
				+ '  |  GO:' + ~~state.UpstreamBoardOK
				+ '  |  TR:' + ~~state.Transfer
				+ '  |  M:' + state.Mode;
			if (serials.Top) {
				msg += '  |  TOP:' + serials.Top;
			}
			if (serials.Bottom) {
				msg += '  | BTM:' + serials.Bottom;
			}
			console.log(msg);
		};

		this.state.on(_E_._CHANGED_, _print_state_);
		this.state.on(_E_._TRANSFERRING_, _print_state_);
		this.state.on(_E_._STOPTRANSFER_, _print_state_);
		this.state.on(_E_._BOARD_ON_, _print_state_);
		this.state.on(_E_._BOARD_OFF_, _print_state_);
		this.state.on(_E_._BOARD_OK_, _print_state_);
		this.state.on(_E_._BYPASS_BOARD_OK_, _print_state_);

		this.state.on(_E_._MODE_, (state, serials) => {
			_print_state_(state, serials);
			this.plugins.setMode(state.Mode);
		});

		// Happens when a new valid serial is set for the state
		this.state.on(_E_._SERIAL_, (state, serials) => {
			this.scannersTop.untrigger();
			this.scannersBottom.untrigger();
			_print_state_(state, serials);
		});

		this.state.on(_E_._TRANSFERRED_, (state, serials, runtimeModeChanged) => {
			_print_state_(state, serials);
			// Only trigger send #!TRANSFER when mode changed from SCAN/ONTHEFLY/NOSCAN to BYPASS
			// If mode changed from BYPASS to SCAN/ONTHEFLY/NOSCAN don't send #!TRANSFER to server
			if (state.Mode != _MODE_._BYPASS_) {
				if (!runtimeModeChanged) { this.plugins.done(); }
			} else {
				if (runtimeModeChanged) { this.plugins.done(); }
			}
		});

		// Happens when a board is forcefully removed (i.e. not because of a transfer)
		this.state.on(_E_._BOARD_OUST_, (state, serial) => {
			this.scannersTop.untrigger();
			this.scannersBottom.untrigger();
			_print_state_(state, serial);
			if (state.Mode != _MODE_._BYPASS_) {
				this.plugins.abort();
			}
		});

		this.state.on(_E_._DOSCAN_, duration => {
			this.scannersTop.trigger(duration);
			this.scannersBottom.trigger(duration);
		});

		// Create the IO controller
		// We create the IO controller after the machine state event handlers are attached
		// because the IO controller is the one that will start changing machine state and start
		// the chain of events
		this.io_controller = new InputOutput(this.state);

		// Start polling to check for a transfer
		this.timer = setInterval(() => {
			this.state.changeState('UpstreamBoardAvailable', this.plugins.getBA() || this.io_controller.getUpstreamBoardAvailable());
			this.state.changeState('DownstreamReady', this.plugins.getMR() || this.io_controller.getDownstreamReady());
			// Check if we should set the serials for plugins
			if (this.state._state.UpstreamBoardAvailable) {
				if (this.state.isTriggeredBy(_VT_._BA_) || (this.state._state.DownstreamReady && this.state.isTriggeredBy(_VT_._MR_))) {
					if (this.state.hasSerials()) {
						// We convert the serial object into individual parameters
						// The reason we do this is because it is easier to document 
						// individual parameters for PlugInValidationBase.setSerials (of plugin_sdk.js)
						// than to document the structure of the serial object
						// Could possibly be remedied by converting project to TypeScript
						const serials = this.state.getSerials();
						this.plugins.setSerials(
							serials.Top, serials.Bottom,
							serials.TopTime, serials.BottomTime);
					}
				}
				if (this.state.isMode(_MODE_._BYPASS_) || this.plugins.getOK()) {
					this.state.changeState('UpstreamBoardOK', true);
				}
				// Additional handling for No scan mode + MR validation due to previous logic not cover this
				// particular condition (BAout not turn on when BAin turned on)
				if (this.state.isMode(_MODE_._NOSCAN_) && this.plugins.getReady() && !this.state._state.Transfer && 
				   ((this.state.isTriggeredBy(_VT_._MR_) && this.state._state.DownstreamReady) || this.state.isTriggeredBy(_VT_._BA_))) {
					this.plugins.setSerials();
				}
				if (this.state.isMode(_MODE_._NOSCAN_) && this.state.isTriggeredBy(_VT_._MR_) && this.plugins.getOK()) {
					this.state.changeState('UpstreamBoardOK', true);
				}
			}
			if (this.state._state.UpstreamBoardOK && this.state._state.DownstreamReady) {
				this.state.changeState('Transfer', true);
			}
		}, 100); // Poll every 0.1 seconds

	}

	setMode(newmode) {
		this.state.changeState('Mode', newmode || _MODE_._SCAN_);
	}

	setPrefixSuffix(prefix, suffix) {
		this.state.changePrefixSuffix(prefix, suffix);
	}

	setValidationTrigger(validationTrigger) {
		this.state.changeValidationTrigger(validationTrigger);
	}

	setRescan(timeout, limit) {
		this.state.changeRescan(timeout, limit);
	}

	setTriggerTime(triggertime) {
		this.state.changeTriggerTime(triggertime);
	}

	setIO(ba_in, ba_out, mr_in, mr_out) {
		this.io_controller.init(ba_in, ba_out, mr_in, mr_out);
	}

	loadPlugIns(names) {
		this.plugins.load(this.state._state.Mode, names);
	}

	/**
	 * Gets an array of the names of the plug-ins that are loaded.
	 */
	getLoadedPlugIns() {
		return this.plugins.getLoadedNames();
	}

	syncPluginConfig(name) {
		this.plugins.syncConfig(name);
	}

	addDummyScanner() {
		this.scannersTop.addDummy(this.state);
	}

	removeDummyScanner() {
		this.scannersTop.removeDummy();
		this.state.reset();
	}

	addScannerTop(scanner) {
		this.scannersTop.add(scanner);
	}

	addScannerBottom(scanner) {
		this.scannersBottom.add(scanner);
	}

	removeScannerTop(scanner) {
		this.scannersTop.remove(scanner);
	}

	removeScannerBottom(scanner) {
		this.scannersBottom.remove(scanner);
	}

	dispose() {
		clearInterval(this.timer);
		this.io_controller.dispose();
		this.plugins.dispose();
		this.scannersTop.removeAll();
		this.scannersBottom.removeAll();
	}

}

module.exports = Flow;