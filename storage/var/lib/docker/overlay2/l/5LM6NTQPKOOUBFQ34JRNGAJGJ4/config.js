'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2018-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const fs = require('fs');
const crypto = require('crypto');
const MachineState = require('./machine_state.js');
const CONFIG_FILE = './storage/config.json';
const VERSION_FILE = './version.json';
const DEFAULT_PASSWORD = '732'; // As per Cogiscan. We use similar value to make it easier for the engineering folks
const DEFAULT_ADMIN_PASSWORD = '999'; // Admin Password (also used to protect against changing to bypass mode)
const DEFAULT_PLUGIN = ['MES'];
const DEFAULT_MODE = MachineState._MODE_._SCAN_;
const DEFAULT_VAL_TRIGER = MachineState._VAL_TRIGGER_._BA_;
const DEFAULT_RESCAN_TIMEOUT = 12; 
const DEFAULT_RESCAN_LIMIT = 2;
const DEFAULT_TRIGGER_TIME = 3; // must be multiple of 0.1s

/**
 * Handles user-configurable settings.
 */
class Config {

    // Reads the on-disk version file and returns it as an json object.
    static getVersion() {
        try {
            return JSON.parse(fs.readFileSync(VERSION_FILE, 'utf8'))
        } catch (e) {
            // If there was an error check if it was because the file does not exist
            if (e.code === 'ENOENT') {
                // The file does not exist so just return an empty version info
                console.log('The version JSON file does not exists.');
                return {};
            } else if (e.message.includes('end of JSON input')) {
                // The file is corrupted for some reason, return an empty version info
                console.log('The version JSON file is possibly corrupted.');
                return {};
            }
            // Rethrow for all other errors
            throw e;
        }
    }

    static exists() {
        return fs.existsSync(CONFIG_FILE);
    }

    /**
     * Reads the on-disk config file and returns it as an object.
     */
    static retrieve() {
        try {
            return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'))
        } catch (e) {
            // If there was an error check if it was because the config file does not exist
            if (e.code === 'ENOENT') {
                // The config file does not exist so just return an empty config
                console.log('The config JSON file does not exists.');
                return {};
            } else if (e.message.includes('end of JSON input')) {
                // The config file is corrupted for some reason, return an empty config
                console.log('The config JSON file is possibly corrupted.');
                return {};
            }
            // Rethrow for all other errors
            throw e;
        }
    }

    // Reads the config file from disk
    // Calls a callback to apply updates to the file
    // Then saves the file back to disk
    static update(callback) {
        // Get the config values on file
        let content = Config.retrieve();
        // Call the callback to apply changes to the config
        callback(content);
        // Save the config values back to file
        content = JSON.stringify(content, null, 2);
        try {
            fs.writeFileSync(CONFIG_FILE, content, 'utf8');
        } catch (e) {
            console.error(e);
        }
    }

    static hashSha256(value) {
        return crypto.createHash('sha256').update(value).digest('hex');
    }

    static verifyPassword(value) {
        return Config.retrieve().PasswordHash == Config.hashSha256(value);
    }

    static verifyAdminPassword(value) {
        return Config.retrieve().AdminPasswordHash == Config.hashSha256(value);
    }

    /**
     * Validates that the config file has the correct format.
     * If it is an older version with the wrong format then it is updated to the newest format.
     * If it does not exists then it's created.
     */
    static validate() {
        // The config file does not exist. Create it and set default values
        Config.update(cfg => Config._validate(cfg));
    }

    static _validate(config) {
        // Set the default password if it does not exist
        if (!config.PasswordHash) {
            // For security purpose, remove showing DEFAULT_PASSWORD value on log 
            // console.log('    Password hash missing. Defaulting to ' + DEFAULT_PASSWORD + '.');
            console.log('    Password hash missing. Creating PasswordHash with default value.');
            config.PasswordHash = Config.hashSha256(DEFAULT_PASSWORD);
        }
        // Set the default admin password if it does not exist
        if (!config.AdminPasswordHash) {
            // For security purpose, remove showing DEFAULT_ADMIN_PASSWORD value on log 
            // console.log('    AdminPassword hash missing. Defaulting to ' + DEFAULT_ADMIN_PASSWORD + '.');
            console.log('    AdminPassword hash missing. Creating AdminPasswordHash with default value.');
            config.AdminPasswordHash = Config.hashSha256(DEFAULT_ADMIN_PASSWORD);
        }
        // Create the Flows array
        if (!config.FlowCount) {
            console.log('   Flow count missing. Defaulting to 1.');
            config.FlowCount = 1;
        }

        if (!config.Flows) {
            console.log('   Flows missing. Creating 2 with default scan mode of \'' + DEFAULT_MODE + '\'.');
            config.Flows = [
                {
                    Mode: DEFAULT_MODE,
                    BarcodePrefix: '',
                    BarcodeSuffix: '',
                    ValidationTrigger: DEFAULT_VAL_TRIGER,
                    RescanTimeout: DEFAULT_RESCAN_TIMEOUT,
                    RescanLimit: DEFAULT_RESCAN_LIMIT,
                    TriggerTime: DEFAULT_TRIGGER_TIME,
                    PlugIns: DEFAULT_PLUGIN
                },
                {
                    Mode: DEFAULT_MODE,
                    BarcodePrefix: '',
                    BarcodeSuffix: '',
                    ValidationTrigger: DEFAULT_VAL_TRIGER,
                    RescanTimeout: DEFAULT_RESCAN_TIMEOUT,
                    RescanLimit: DEFAULT_RESCAN_LIMIT,
                    TriggerTime: DEFAULT_TRIGGER_TIME,
                    PlugIns: DEFAULT_PLUGIN
                }
            ];
        }

        // In older versions of the config file, remove properties that
        // should be for Flow 0
        const flow0 = config.Flows[0];
        if (config.Mode) {
            console.log('   Moving deprecated Mode into flow 0.');
            flow0.Mode = config.Mode;
            delete config.Mode;
        }
        if (config.BarcodePrefix) {
            console.log('   Moving deprecated BarcodePrefix into flow 0.');
            flow0.BarcodePrefix = config.BarcodePrefix;
            delete config.BarcodePrefix;
        }
        if (config.BarcodeSuffix) {
            console.log('   Moving deprecated BarcodeSuffix into flow 0.');
            flow0.BarcodeSuffix = config.BarcodeSuffix;
            delete config.BarcodeSuffix;
        }
        if (config.PlugIns) {
            console.log('   Moving deprecated PlugIns into flow 0.');
            flow0.PlugIns = config.PlugIns;
            delete config.PlugIns;
        }

        // Upgrade older versions of config file that have missing properties
        const flow1 = config.Flows[1];
        if (!flow0.ValidationTrigger) {
            flow0.ValidationTrigger = DEFAULT_VAL_TRIGER;
        }
        if (!flow1.ValidationTrigger) {
            flow1.ValidationTrigger = DEFAULT_VAL_TRIGER;
        }
        if (!flow0.RescanTimeout) {
            flow0.RescanTimeout = DEFAULT_RESCAN_TIMEOUT;
        }
        if (!flow1.RescanTimeout) {
            flow1.RescanTimeout = DEFAULT_RESCAN_TIMEOUT;
        }
        if (!flow0.RescanLimit) {
            flow0.RescanLimit = DEFAULT_RESCAN_LIMIT;
        }
        if (!flow1.RescanLimit) {
            flow1.RescanLimit = DEFAULT_RESCAN_LIMIT;
        }
        if (!flow0.TriggerTime) {
            flow0.TriggerTime = DEFAULT_TRIGGER_TIME;
        }
        if (!flow1.TriggerTime) {
            flow1.TriggerTime = DEFAULT_TRIGGER_TIME;
        }
    }

}

module.exports = Config;