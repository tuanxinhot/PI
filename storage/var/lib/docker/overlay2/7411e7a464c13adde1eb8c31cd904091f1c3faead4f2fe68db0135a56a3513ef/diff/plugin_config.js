'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2020-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const fs = require('fs');
const Yaml = require('./resources/js/js-yaml.min.js');
const YAML_DIR = './resources/Assets/plugin_yaml';
const CONFIG_DIR = './storage/_configs';

class PlugInConfig {

	/**
	 * Returns the configuration definition YAML for the given plug-in. 
	 * @param {string} pluginName 
	 */
	static getConfigDefinition(pluginName) {
		// Load the YAML definition file
		const raw = fs.readFileSync(`${YAML_DIR}/${encodeURI(pluginName)}.yaml`, 'utf-8',
			e => {
				if (e) {
					console.log(`Plug-in ${pluginName}.f${flowindex}: Error trying to load config defintion .yaml file.`)
					console.error(e);
				}
			})
		return Yaml.safeLoadAll(raw);
	}

	/**
	 * Returns configuration variables (i.e. config item name, with defaults if available) in a single-level for the given plug-in. 
	 * @param {string} pluginName 
	 */
	static getFlattenedConfigDefinitionVars(pluginName) {
		// Declare the helper lambda to deserialize definition key pairs
		const flatten_ = def => {
			let vars = [];
			// If children tag is present that means that this is a multi level config item, continue digging deeper
			if ('children' in def['config_item']) {
				def['config_item']['children'].forEach(node => vars = vars.concat(flatten_(node)))

				// No children tag present means its at the final level, record down the definition name and its default if available
			} else {
				const def_name = def['config_item']['config_name'];
				const def_value = 'default' in def['config_item'] ? def['config_item']['default'] : null;
				const v = { [def_name]: def_value };
				vars.push(v);
			}
			return vars;
		}

		const definition = PlugInConfig.getConfigDefinition(pluginName);

		// Get each config variable in the definition
		let result = []
		definition.forEach(node => result = result.concat(flatten_(node)));

		// Using the deserialized array of definition key pairs, unpack them and returns as a single level JSON object
		let config = {}
		result.forEach(v => { for (let ele in v) { config[ele] = v[ele]; } });

		return config;
	}

	// return related information to check the value return from html
	//eg: config_name, datatype, min, max, max_length,min_length
	static getWholeYamlConfig(pluginName) {
		// Declare the helper lambda to deserialize definition key pairs
		const flatten_ = def => {
			const vars = {};
			// If children tag is present that means that this is a multi level config item, continue digging deeper
			if ('children' in def['config_item']) {
				def['config_item']['children'].forEach(node => vars = { ...vars, ...flatten_(node) })

			} else {
				const def_name = def['config_item']['config_name'];
				vars[def_name] = def['config_item'];
			}
			return vars;
		}
		const definition = PlugInConfig.getConfigDefinition(pluginName);
		// Get each config variable in the definition
		let result = {}
		definition.forEach(node => result = { ...result, ...flatten_(node) });
		return result;
	}

	static getConfigFilename(pluginName, flowindex) {
		return `${CONFIG_DIR}/${pluginName}.f${flowindex}.json`;
	}

	/**
	 * Returns the configurations for the given plug-in and flow as an object.
	 * @param {string} pluginName The name of the plug-in.
	 * @param {number} flowindex The flow index for the plug-in. 
	 */
	static getConfig(pluginName, flowindex) {
		console.log(`Plug-in ${pluginName}.f${flowindex}: Loading config.`);
		const vars = PlugInConfig.getFlattenedConfigDefinitionVars(pluginName);
		const cfg_file = PlugInConfig.getConfigFilename(pluginName, flowindex);
		if (fs.existsSync(cfg_file)) {
			let vals = fs.readFileSync(cfg_file, 'utf-8',
				e => {
					if (e) {
						console.log(`Plug-in ${pluginName}.f${flowindex}: Error trying to load config file.`);
						console.error(e);
						return null;
					}
				});

			if (vals) {
				let vars2 = vars;
				vals = JSON.parse(vals);
				if (Object.keys(vals).length > 0) {
					let writeConfig = false;
					Object.keys(vals).forEach( e => delete vars2[e] );
					if (Object.keys(vars2).length > 0) {
						writeConfig = true;
					}
					vars2 = { ...vals, ...vars2 };
					if (writeConfig) {
						PlugInConfig.setConfig(pluginName, flowindex, vars2);
					}
					return vars2;
				} else {
					return null;
				}
			} else {
				return null;
			}
		}
		// If processing reaches here then the config file does not exist, create it with defaults from the YAML definition
		console.log(`Plug-in ${pluginName}.f${flowindex}: Config file not found. Attempting to create.`);
		if (Object.keys(vars).length === 0) {
			console.log(`Plug-in ${pluginName}.f${flowindex}: YAML definition is invalid or empty.`);
			return null;
		}
		PlugInConfig.setConfig(pluginName, flowindex, vars);
		return vars;
	}

	// Updates the config files with the latest settings
	static setConfig(pluginName, flowindex, config) {
		if (!fs.existsSync(CONFIG_DIR)) {
			fs.mkdirSync(CONFIG_DIR);
		}
		if (typeof config !== 'string' && !(config instanceof String)) {
			config = JSON.stringify(config);
		}
		fs.writeFileSync(PlugInConfig.getConfigFilename(pluginName, flowindex), config, 'utf-8',
			e => {
				if (e) {
					console.log(`Plug-in ${pluginName}.f${flowindex}: Error trying to save config file.`);
					console.error(e);
				} else {
					console.log(`Plug-in ${pluginName}.f${flowindex}: Config saved.`);
				}
			});
	}
	/**
	 * Gets all the available config values from all flows for a particular plugin
	 * @param {string} pluginName
	 * @returns {config name:config value}
	 * eg {'network_interface':'eth0'}
	 */

	static getAllAvailableConfig(pluginName) {
		const FlowCollector = require('./flow_collector.js');
		const flowCount = FlowCollector.getSupportedFlowCount()
		let configs = []

		for (let i = 0; i < flowCount; i++) {
			const cfg_file = PlugInConfig.getConfigFilename(pluginName, i);
			if (fs.existsSync(cfg_file)) configs.push(PlugInConfig.getConfig(pluginName, i))
		}

		return configs
	}
	/**
	 * Gets all the available config values from all plugins for both flow
	 * @returns  {'plugin':pluginname, config name:config value}
	 *  eg {'plugin':'MES', 'network_interface':'eth0'}
	 */
	static getAvailableConfigperFlows() {
		const PlugIns = require('./plugin_collector.js');
		const Pluginlist = PlugIns.getAvailablePlugins()
		let configs = []
		Pluginlist.forEach(plugin => {
			// Get plugin name and config the
			const pluginName = plugin.PlugIn.getName()
			// Get the setting values of the flows (both flows) for the plugin
			let items = PlugInConfig.getAllAvailableConfig(pluginName)
			// Map tge value with plugin name
			items.forEach(item => {
				let pluginpair = { 'plugin': pluginName }
				pluginpair[Object.keys(item)] = Object.values(item)
				configs.push(pluginpair)
			})
		})
		return configs
	}

}

module.exports = PlugInConfig;