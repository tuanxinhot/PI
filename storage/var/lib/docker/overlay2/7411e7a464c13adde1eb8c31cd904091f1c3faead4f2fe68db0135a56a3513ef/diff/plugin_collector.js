'use strict';
// ╓─────────────────────────────────────────╖
// ║ Copyright 2019-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const fs = require('fs');
const path = require("path");
const PlugIns = require('./plugin_sdk.js');
const Base = PlugIns.Base;
const _PLUGINTYPE_ = PlugIns._PLUGINTYPE_;
const PLUGINS_DIR = './plugins';
const ICONS_DIR = './resources/Assets/plugin_icons';
const YAML_DIR = './resources/Assets/plugin_yaml';
var transfer_to_resource_folder_done = false;

class PlugInCollector {

	constructor(initialstate) {
		PlugInCollector.transferFiles();
		this.plugins = [];
		this.flowindex = initialstate.flowindex;
        process.on('SIGINT', () => { this.dispose(); });
		process.on('SIGTERM', () => { this.dispose(); });
        process.on('SIGQUIT', () => { this.dispose(); });
        process.on('SIGABRT', () => { this.dispose(); });
	}

    static validatePlugin(filename) {
		if (!filename.endsWith('.js')) {
			return null;
		}
        let lib = null;
        try {
            // Try to load the file as a library
			lib = require(filename);
			// Try to get the plug-in's name
            lib.PlugIn.getName();
        } catch (e) {
            // ...an error probably means the file has no exported modules
            // or it does not contain a getName() method
            // console.log(e)
            return null;
		}
		if (Base.isPrototypeOf(lib.PlugIn)) {
			return lib;
		}
		return null;
    }

    static getAvailablePlugins() {
		// TODO May impact performance if there are a lot of directories to visit

		const plugins = []; // To store a list of plugin js files across different directories
		// Scan for a list of directories inside plugins folder first
		fs.readdirSync(PLUGINS_DIR, {withFileTypes: true})
			.filter(f => f.isDirectory())
			.map(f => f.name)
			.forEach(dir => {
				fs.readdirSync(`${PLUGINS_DIR}/${dir}`)
					.filter(file => file == `${dir}.js`)
					.map(file => { return PlugInCollector.validatePlugin(`${PLUGINS_DIR}/${dir}/${file}`) })
					.filter(lib => lib !== null)
					.forEach(lib => plugins.push(lib));
			})
		return plugins;
	}

	// Transfers plugin icons and config schema YAML to resource folder on startup
	static transferFiles() {
		if (transfer_to_resource_folder_done) { return; }

		// Declare the helper lambda that will copy the given file based on the plug-in name
		const copy_ = (dir, name, ext, target_dir) => {
			fs.copyFile(`${PLUGINS_DIR}/${dir}/${dir}.${ext}`, encodeURI(`${target_dir}/${name}.${ext}`), 
				e => {
					if (e) { 
						if (e.code === 'ENOENT') { console.log(`Plug-in ${name}: ${dir}.${ext} file itself, source or destination directory does not exist.`); }
						else { console.error(e); }
					}
				});
		}

		// TODO Image formats that we want to support? only ico supported for now, hardcoded into process
		fs.readdirSync(PLUGINS_DIR, {withFileTypes: true})
			.filter(f => f.isDirectory())
			.map(f => f.name)
			.forEach(dir => {
				fs.readdirSync(`${PLUGINS_DIR}/${dir}`)
					.filter(file => file == `${dir}.js`)
					.map(file => PlugInCollector.validatePlugin(`${PLUGINS_DIR}/${dir}/${file}`))
					.filter(lib => lib !== null)
					.forEach(lib => {
						const name = lib.PlugIn.getName();
						copy_(dir, name, 'ico', ICONS_DIR);
						copy_(dir, name, 'yaml', YAML_DIR);
						console.log(`Plug-in ${name}: .ico and .yaml files transferred.`);
					})
			});
		transfer_to_resource_folder_done = true;
	}

	getLoadedNames() {
		return this.plugins.map(p => p.constructor.getName());
	}

	/**
	 * Ensures that the given list of plug-in names are loaded.
	 * If a plug-in is already loaded, nothing is done.
	 * If a plug-in is not yet loaded then it is loaded and its mode set.
	 * Any already loaded plug-ins not in the list are unloaded and disposed.
	 */
	load(mode, names) {
		if (!names) {
			names = [];
		} else if (typeof names === 'string' || names instanceof String) {
			names = [ names ];
		}
		// Remove all disabled plug-ins
		let idx = 0;
		while (idx < this.plugins.length) {
			let name = this.plugins[idx].constructor.getName();
			// If the current plug-in is in the enabled list then move to the next plug in
			if (names.includes(name)) {
				console.log(`Plug-in ${name}: Retained.`);
				idx++;
			} else {
				let p = this.plugins[idx];
				// This plug-in is not in the enabled list, remove it
				this.plugins.splice(idx, 1);
				// Dispose the plug-in
				p.dispose();
				console.log(`Plug-in ${name}: Unloaded.`);
			}
		}

		// Add in enabled plug-ins that do not already exists
		const available = PlugInCollector.getAvailablePlugins()
		const loaded = this.getLoadedNames();
		names.forEach(name => {
			// If the plug-in is not already loaded then load it
			if (!loaded.includes(name)) {
				const target = available.find(p => p.PlugIn.getName() == name);
				if (target) {
					//create new isntance
					const p = new target.PlugIn({ flowindex: this.flowindex });
					this.plugins.push(p);
					p.setMode(mode);
					console.log(`Plug-in ${name}: Loaded.`);
				} else {
					console.log(`Plug-in ${name}: Not found and will not be loaded.`);
				}
			}
		});
	}

	syncConfig(name) {
		const target = this.plugins.find(p => p.constructor.getName() == name);
		if (target) { target.syncConfig(); }
	}

	getReady() {
		return this.plugins.every(p => p.getReady());
	}

	getStatus() {
		return this.plugins.map(p => {
			// Get the status for each plugin type
			let _status = false;
			switch(p.pluginType) {
				case _PLUGINTYPE_._VAL_: 	_status = p.getOK(); break;
				case _PLUGINTYPE_._BA_:		_status = p.getBA(); break;
				case _PLUGINTYPE_._MR_:		_status = p.getMR(); break;
			}
			return {
				Name: p.constructor.getName(),
				Info: p.getInfo(), 
				Ready: p.getReady(),
				Ok: _status
			}
		});
	}

	forEach(type, callbackfn) {
		this.plugins.forEach(p => {
			if (p.pluginType == type) {
				callbackfn(p);
			}
		});
	}

	// Call different ok method base on the plugin type (BA, VAL, MR)
	every(type, callbackfn) {
		if (!this.plugins || !this.plugins.length) {
			// No plugins enabled, default return false
			return false;
		}
		// check for all board available plugin return true or false
		const _filtered = this.plugins.filter(p => p.pluginType == type);
		if (_filtered.length == 0) {
			// No plugins of the given type, default return false
			return false;
		}
		return _filtered.every(p => callbackfn(p));
	}

	setMode(mode) {
		this.forEach(_PLUGINTYPE_._VAL_, p => p.setMode(mode));
	}

	setSerials(top, bottom, topTime, bottomTime) {
		this.forEach(_PLUGINTYPE_._VAL_, p => p.setSerials(top, bottom, topTime, bottomTime));
	}

	getOK() {
		return this.every(_PLUGINTYPE_._VAL_, p => p.getOK());
	}

	abort() {
		this.forEach(_PLUGINTYPE_._VAL_, p => p.abort());
	}

	done() {
		this.forEach(_PLUGINTYPE_._VAL_, p => p.done());
	}

	getBA() {
		return this.every(_PLUGINTYPE_._BA_, p => p.getBA());
	}

	getMR() {
		return this.every(_PLUGINTYPE_._MR_, p => p.getMR());
	}

	dispose() {
		while (this.plugins && this.plugins.length > 0) {
			this.plugins.pop().dispose();
		}
		process.off('SIGINT', () => { this.dispose(); });
		process.off('SIGTERM', () => { this.dispose(); });
		process.off('SIGQUIT', () => { this.dispose(); });
		process.off('SIGABRT', () => { this.dispose(); });
	}

}

module.exports = PlugInCollector;