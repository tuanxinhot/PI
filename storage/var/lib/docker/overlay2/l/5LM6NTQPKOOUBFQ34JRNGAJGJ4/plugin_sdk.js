'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2020-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const Utils = require('./utils.js');
const PlugInConfig = require('./plugin_config.js');

const _PLUGINTYPE_ = {
    _NA_: 0,
    _BA_: 1000,
    _VAL_: 2000,
    _MR_: 3000
}

function NotImplementedError(methodname) {
    this.name = 'NotImplementedError';
    this.message = "The '" + methodname + "' method for your plug-in has not been implemented.";
}
NotImplementedError.prototype = Error.prototype;

class PlugInBase {

    constructor(initialstate) {
        this.flowindex = initialstate.flowindex;
        this.pluginType = _PLUGINTYPE_._NA_;
        this.postMessageToUi = null;
    }

    /**
     * Notifies this instance to synchronize its internal state with its underlying configuration file.
     * The configuration file is changed externally through the UI. When that happens, this method is called.
     */
    syncConfig() {
        // No return value is expected from this method
        throw new NotImplementedError('syncConfig');
    }

    /**
     * Returns the current text status of the plug-in.
     * E.g. for a temperature threshold plug-in it could return the current temperature reading.
     * The string returned should not exceed 40 characters.
     * @returns {string}
     */
    getInfo() {
        throw new NotImplementedError('getInfo');
    }

    /**
     * Returns whether the plug-in is in a ready state.
     * E.g. a gas sensor plug-in should return false until it has warmed up and
     * its readings have stabilize, then it should return true.
     * Note that the return from this function is used for display only and is not employed in any processing logic.
     * However, it should normally be part of the logic that makes up the return of the getOK() method.
     * This is at the discretion of the plug-in developer.
     * @returns {boolean}
     */
    getReady() {
        throw new NotImplementedError('getReady');
    }

    /**
     * Informs the plug-in that it should release any resources held, 
     * e.g. listening http servers, database connections, etc. and perform any required clean ups.
     * This method is called when PICO is shutting down or the user has
     * disabled this plug-in from the list of available plug-ins.
     */
    dispose() {
        // No return value is expected from this method
        throw new NotImplementedError('dispose');
    }

}

// Base Class for Board Available plugin
class PlugInBoardAvailableBase extends PlugInBase {

    constructor(initialstate) {
        super(initialstate);
        this.pluginType = _PLUGINTYPE_._BA_;
    }

    /**
     * Emulates a physical board available signal and informs the plug-in that 
     * board is available to move to the downstream machine.
     * E.g. listening tcp/http servers for the BA signal and call 
     * this method.
     * @returns {boolean}.
     */
    getBA() {
        // This method is called and return board available signal.
        // Pico will check for the value return (BA IN) rather than getting
        // signal from io port.
        throw new NotImplementedError('getBA');
    }

}

// Base Class for Machine Ready plugin
class PlugInMachineReadyBase extends PlugInBase {

    constructor(initialstate) {
        super(initialstate);
        this.pluginType = _PLUGINTYPE_._MR_;
    }

    /**
     * Emulates board Machine Ready signal and informs the plug-in that 
     * next machine is ready to receive board.
     * E.g. listening tcp/http client for the MR OUT signal and call 
     * this method.
     * @returns {boolean}.
     */
    getMR() {
        // This method is called and return Machine Ready signal.
        // Pico will check for the value return (MR OUT) rather than getting
        // signal from io port.
        throw new NotImplementedError('getMR');
    }

}

// Base Class for validation plugin
class PlugInValidationBase extends PlugInBase {

    constructor(initialstate) {
        super(initialstate);
        this.pluginType = _PLUGINTYPE_._VAL_;
    }

    /**
     * Informs the plug-in that a new mode has been set.
     * @param {string} mode The new mode. 
     */
    setMode(mode) {
        throw new NotImplementedError('setMode');
    }

    /**
     * Informs the plug-in that a board is available with the given top and bottom serial numbers.
     * If 'top' and 'bottom' are 'undefined' then PICO is in no-scan mode.
     * The implementation should be robust enough to be called repeatedly with the same serial numbers.
     * @param {string | undefined} top The last scanned top serial number. This could be undefined.
     * @param {string | undefined} bottom The last scanned bottom serial number. This could be undefined.
     * @param {number | undefined} topTime The date and time of the last top scan. This could be undefined.
     * @param {number | undefined} bottomTime The date and time of the last bottom scan. This could be undefined.
    */
	setSerials(top, bottom, topTime, bottomTime) {
		throw new NotImplementedError('setSerials');
	}

    /**
     * Returns whether the board from the previous setSerials() call has been OK-ed 
     * to be transferred to the downstream machine.
     * @returns {boolean}.
     */
    getOK() {
        // This method is called often (everytime any state in PICO changes) and should
        // therefore return quickly.
        // Ideally it should read the value from a single field and not be doing any processing.
        throw new NotImplementedError('getOK');
    }

    /**
     * Informs the plug-in that the board from the previous setSerials() call has been abnormally removed.
     * This could happen for any number of reasons but normally because an operator 
     * manually removes the board from the conveyor.
     * At this point, the plug-in should reset its internal state.
     */
    abort() {
        // No return value is expected from this method
        throw new NotImplementedError('abort');
    }

    /**
     * Informs the plug-in that the board from the previous setSerials() call has 
     * been transferred successfully to the downstream machine.
     * At this point, the plug-in should reset its internal state.
     */
    done() {
        // No return value is expected from this method
        throw new NotImplementedError('done');
    }

}

class PlugInSdk {

    /**
     * Returns plugin name when getConfig is called from <plugin>.js
     */
    static getPluginName() {
        const stack = new Error().stack.split('\n');
        // find the correct plugins path with regex 
        // eg: /plugins/xxx/xxx.js
        const has_plugin_folder = /[\\|\/]plugins[\\|\/][a-z_\-\s0-9\.]+[\\|\/][a-z_\-\s0-9\.]+/;
        const line_index = stack.findIndex(line => has_plugin_folder.test(line));
        const plugin_line = stack[line_index];
        const plugin_path = plugin_line.slice(
            plugin_line.lastIndexOf('(') + 1,
            plugin_line.lastIndexOf('.js') + 3
        );
        return require(plugin_path).PlugIn.getName();
    }

    /**
     * Returns the configurations for the given plug-in and flow as an object.
     * @param {number} flowindex The flow index for the plug-in.
     * @param {string} pluginName The plugin name, this can be empty, if it is empty,
     * it will call the PlugInSdk.getPluginName() to get the plugin name
     */
    static getConfig(flowindex, pluginName = null) {
        if (!pluginName) {
            pluginName = PlugInSdk.getPluginName()
        }
        return PlugInConfig.getConfig(pluginName, flowindex);
    }

    /**
     * Returns the static IP for the given network interface name.
     * @param {string} interfaceName The name of the network interface which you want to get the static IP for (.e.g eth0, wlan0, etc.)
     * @returns {string} Returns the static IP if the network interface is found, otherwise returns null. 
     */
    static getStaticIp(interfaceName) {
        const matched = Utils.getStaticIps().filter(iface => iface.name === interfaceName);
        if (matched && matched.length > 0) {
            return matched[0].ip;
        }
        return null;
    }

}

module.exports = {
    BoardAvailableBase: PlugInBoardAvailableBase,
    ValidationBase: PlugInValidationBase,
    MachineReadyBase: PlugInMachineReadyBase,
    Sdk: PlugInSdk,
    Base: PlugInBase,
    _PLUGINTYPE_: _PLUGINTYPE_
}