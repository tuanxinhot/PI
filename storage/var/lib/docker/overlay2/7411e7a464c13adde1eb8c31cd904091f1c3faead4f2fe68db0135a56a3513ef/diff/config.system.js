'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2020 - Jabil Circuit Inc      ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const fs = require('fs');
const utils = require('./utils.js');
const IMAGE_CONFIG_FILE = './config.system.json'; // The config file at the time the image was built
const SAVED_CONFIG_FILE = './storage/config.system.json'; // The config file that's been copied to the storage folder

const updaters = [];
var settings = null;
var scheduler;

function getSettings(onUpdate) {
    if (onUpdate instanceof Function) {
        updaters.push(onUpdate);
    } else {
        console.log(`CFG.SYS: Expected a function but got ${onUpdate}. Fix in calling code.`);
    }
    return settings;
}

function retrieve(file) {
    try {
        const cfg = JSON.parse(fs.readFileSync(file, 'utf8'))
        if (cfg.__ts__) {
            cfg.__ts__ = new Date(cfg.__ts__);
        }
        return cfg;
    } catch (e) {
        // If there was an error check if it was because the config file does not exist
        if (e.message.includes('end of JSON input')) {
            // The config file is corrupted for some reason, return an empty config
            console.log(`CFG.SYS: ${file} is possibly corrupted.`);
            return {};
        } else {
            // Rethrow for all other errors
            throw e;
        }
    }
}

function load() {
    const copy_and_reload = () => {
        console.log('CFG.SYS: Copying image config file to storage.');
        fs.copyFileSync(IMAGE_CONFIG_FILE, SAVED_CONFIG_FILE);
        settings = retrieve(SAVED_CONFIG_FILE);
    }

    // If json file exists in storage, check the timestamp, 
    // if the image version is newer, copy it and overwrite the version in storage
    if (fs.existsSync(SAVED_CONFIG_FILE)) {
        settings = retrieve(SAVED_CONFIG_FILE);
        const image_cfg = retrieve(IMAGE_CONFIG_FILE);
        if (settings.__ts__ && image_cfg.__ts__ && image_cfg.__ts__ > settings.__ts__) {
            copy_and_reload();
        }
    } else {
        // If the json file does not exist in storage, copy the image's copy to storage
        copy_and_reload();
    }
    console.log(`CFG.SYS: Loaded config timestamped at ${settings.__ts__}.`);

    let check_delay_millisecs = settings.sys.check_for_updates_mins * 60 * 1000;
    const check_for_updates = async () => {
        try {           
            // Get the timestamp of the latest config from the API
            const ts_response = await utils.httpGet(`https://${settings.hq.endpoint}${settings.sys.ts_api}`);
            if (!ts_response.ok) {
                if (ts_response.error) {
                    console.log('CFG.SYS: Error getting timestamp from API.');
                    console.error(ts_response.error);
                } else {
                    console.log(`CFG.SYS: [${settings.sys.ts_api}] ${ts_response.response.statusCode} ${ts_response.response.statusMessage}.`);
                }
                return;
            }
            
            // Check if the timestamp of the update is newer, if yes then save the update
            const latest_ts = new Date(ts_response.data);
            if (latest_ts <= settings.__ts__) {
                return;
            }
                
            // Fetch the latest config
            const cfg_response = await utils.httpGet(`https://${settings.hq.endpoint}${settings.sys.fetch_api}`);
            if (!cfg_response.ok) {
                if (cfg_response.error) {
                    console.log('CFG.SYS: Error getting latest config from API.');
                    console.error(cfg_response.error);
                } else {
                    console.log(`CFG.SYS: [${settings.sys.fetch_api}] ${cfg_response.response.statusCode} ${cfg_response.response.statusMessage}.`);
                }
                return;
            }

            // Save the latest config
            console.log('CFG.SYS: Fetched config is latest. Saving and applying it.');
            fs.writeFileSync(SAVED_CONFIG_FILE, cfg_response.data);
            settings = retrieve(SAVED_CONFIG_FILE);
            console.log(`CFG.SYS: Fetched config timestamped at ${settings.__ts__}.`);
            
            // Invoke all updaters to update their local references of the settings
            updaters.forEach(updater => updater(settings));

            // If the check for updates interval has changed then clear the timer
            // It will be recreated in the finally clause
            const new_check_delay_millisecs = settings.sys.check_for_updates_mins * 60 * 1000;
            if (new_check_delay_millisecs != check_delay_millisecs && scheduler) {
                console.log(`CFG.SYS: Scheduling updated to ${new_check_delay_millisecs/60000}mins.`);
                clearInterval(scheduler);
                scheduler = null; // Set to null so that it's recreated below
                check_delay_millisecs = new_check_delay_millisecs;
            }

        } finally {
            if (!scheduler) {
                console.log(`CFG.SYS: Starting schedule to check for updates every ${check_delay_millisecs/60000}mins.`);
                scheduler = setInterval(check_for_updates, check_delay_millisecs);
            }
        }
    }
    
    // Check for updates immediately, this also starts the scheduler
    check_for_updates();

}


// If running as a script, i.e. being called from Dockerfile
// then apply a timestamp to config.system.json
if (!module.parent) {
    // Get the config and update the __ts__ value
    const img_cfg = retrieve(IMAGE_CONFIG_FILE);
    img_cfg.__ts__ = new Date();
    fs.writeFileSync(IMAGE_CONFIG_FILE, JSON.stringify(img_cfg, null, 4));
    console.log(`CFG.SYS: Timestamp updated to ${img_cfg.__ts__}.`);
}

module.exports = {
    getSettings: getSettings,
    load: load
};