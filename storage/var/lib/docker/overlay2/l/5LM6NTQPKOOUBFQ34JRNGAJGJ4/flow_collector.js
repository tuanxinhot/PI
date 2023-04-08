'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2020-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const Config = require('./config.js');
const Utils = require('./utils.js');
const Flow = require('./flow.js');
const SerialScanner = require('./scanner_serial.js');

// Set the IO pins based on kernel version 
// Jabil Pi OS kernel version having new mapped pins: 4.19.65 (i.e. 4.19.66 and above)
const SUPPORTED_FLOWS_COUNT = 2  // This is a hardcoded value that provides the number of flows that we support for now
const VER = Utils.getKernelVersion();
const PINS = Utils.compareVersion(VER, '4.19.65') == 1
	? [
		{
			_BA_IN: 502,
			_MR_IN: 503,
			_DQ_OUT: 496,
			_TR_OUT: 497,
			_TRIGGER: 18
		},
		{
			_BA_IN: 500,
			_MR_IN: 501,
			_DQ_OUT: 498,
			_TR_OUT: 499,
			_TRIGGER: 24
		}
	]
	: [
		{
			_BA_IN: 510,
			_MR_IN: 511,
			_DQ_OUT: 504,
			_TR_OUT: 505,
			_TRIGGER: 18
		},
		{
			_BA_IN: 508,
			_MR_IN: 509,
			_DQ_OUT: 506,
			_TR_OUT: 507,
			_TRIGGER: 24
		}
	];

class FlowCollector {

	constructor() {
		this._flows = [];
		this.sync(true);
	}

	static getSupportedFlowCount() {
		return SUPPORTED_FLOWS_COUNT
	}

	/**
	 * Synchronises the Flow instances (including number of instances) with the configuration file.
	 */
	sync(includePlugins = false) {
		const config = Config.retrieve();

		// As per discussion on Aug 28, 2021 between JinHo, YeePing and FungHan,
		// to push out changes for EMS SMT Connectivity Solution (ESCS) on time
		// we will need to hardcode handling of adding & removing bottom scanners
		// The UI for assigning scanners to flow + [top|bottom] was mutually
		// agreed to become code debt
		// ----------------------------------------------------------------------
		// The below are hard coded logic in-lieu of the UI:
		// 1) When in single lane (i.e. ESCS use case) then we add the 
		//    second serial scanner as the bottom scanner if it has not
		//    already been added
		const _check_to_add_bottom_scanner_for_single_lane_ = 
			() => {
				if (config.FlowCount != 1) { return; }
				const f0_bottoms = this._flows[0].scannersBottom;
				const serial_count = f0_bottoms.scanners.filter(s => s instanceof SerialScanner).length;
				if (serial_count > 0) { return; }
				f0_bottoms.add(new SerialScanner('/dev/ttySC1', 9600, PINS[1]._TRIGGER));
			};
		// 2) When changing from single lane to dual lane, remove the bottom
		//    scanner from flow 0 as it will need to be assigned as the 
		//    top scanner of flow 1
		const _remove_bottom_scanner_if_switching_to_dual_lane_ =
			() => {
				if (this._flows.length == 0 || config.FlowCount == 1) { return; }
				const f0_bottoms = this._flows[0].scannersBottom;
				if (f0_bottoms.count() == 0) { return; }
				f0_bottoms.removeAll();
			};

		// Remove excess flows if any
		while (this._flows.length > config.FlowCount) {
			const flow = this._flows.pop();
			flow.dispose();
			console.log('Removed and disposed flow ' + flow.index + '.');

		}
		_remove_bottom_scanner_if_switching_to_dual_lane_();
		// Add all missing flows
		for (let i = this._flows.length; i < config.FlowCount; i++) {
			console.log('Creating flow ' + (i + 1) + '.');
			const flow = new Flow(i);
			this._flows.push(flow);
			const pins = PINS[i];
			flow.addScannerTop(new SerialScanner('/dev/ttySC' + i, 9600, pins._TRIGGER));
			flow.setIO(pins._BA_IN, pins._DQ_OUT, pins._MR_IN, pins._TR_OUT);
		}
		_check_to_add_bottom_scanner_for_single_lane_();
		// Update all flows
		for (let i = 0; i < this._flows.length; i++) {
			const cfg = config.Flows[i];
			const flow = this._flows[i];
			console.log(`Configuring flow ${i + 1} to ${cfg.Mode}. ${cfg.BarcodePrefix || '<nil>'} ${cfg.BarcodeSuffix || '<nil>'}`);
			flow.setMode(cfg.Mode);
			flow.setPrefixSuffix(cfg.BarcodePrefix, cfg.BarcodeSuffix);
			flow.setValidationTrigger(cfg.ValidationTrigger);
			flow.setRescan(cfg.RescanTimeout, cfg.RescanLimit);
			flow.setTriggerTime(cfg.TriggerTime);
			// When calling from the constructor, we need to sync plugins
			// When calling from http_interface.js, we don't need to sync plugins as only flow settings would be changed
			if (includePlugins) {
				flow.loadPlugIns(cfg.PlugIns);
			}
		}

		this._flows.forEach(x => {
			// Loop all available plugins
			let targetPropertyName = 'postMessageToUi';
			x.plugins.plugins.forEach(y => {
				let funcNames = Object.getOwnPropertyNames(y).filter(z => z == targetPropertyName);
				if (funcNames.length == 1 && y[targetPropertyName] == null) {
					console.log(`Assigning method to postMessageToUi property for ${y.constructor.getName()} plugin.`);
					// Hook up a function that call messageHandler when MES send a #!MSGBEEP or #!MESSAGE signal
					y[targetPropertyName] = (message, time = 5000) => { 
						x.state._messageHandler.postMessage(message, time);
					}
				} else if (funcNames.length == 1 && y[targetPropertyName] != null) {
					console.log(`postMessageToUi property for ${y.constructor.getName()} plugin is not null. Skip method assigning.`);
				} else {
					console.log(`postMessageToUi property not found for ${y.constructor.getName()} plugin. Skip method assigning.`);
				}
			});
		});
	}

	syncPluginConfig(name, flowindex) {
		this.getFlow(flowindex).syncPluginConfig(name);
	}

	setResumeScanTrue() {
		this._flows[0].state.setResumeTestTrue();
	}

	turnOffAllOutputs() {
		this._flows[0].io_controller.turnOffBaMrOut();
	}

	getState() {
		return this._flows.map((f, i) => {
			return {
				'flow': i,
				'barcodes': f.state.getBarcodes(),
				'state': f.state.getState(),
				'config': f.state.getConfig(),
				'ok': f.plugins.getOK(),
				'plugins': f.plugins.getStatus(),
				'last_message': f.state.getLastMessage(),
				'resume_scan': f.state.getResumeTest()
			}
		});

	}

	getFlow(index) {
		return this._flows[index]
	}


	[Symbol.iterator]() {
		var index = -1;
		return {
			next: () => ({
				value: this._flows[++index],
				done: !(index in this._flows)
			})
		}
	}

}

module.exports = FlowCollector;