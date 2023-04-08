'use strict';
// ╓─────────────────────────────────────────╖
// ║ Copyright 2019-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Product Team

const fs = require('fs');
const execSync = require("child_process").execSync;
const os = require("os");
const PlugIns = require('./plugin_sdk.js');
const ValidationBase = PlugIns.ValidationBase;
const BoardAvailableBase = PlugIns.BoardAvailableBase;
const MachineReadyBase = PlugIns.MachineReadyBase;
const _PLUGINTYPE_ = PlugIns._PLUGINTYPE_;

const PLUGINS_DIR = 'plugins';

const args = process.argv.splice(2);
if (args.length < 1) {
	console.log('Please specify the folder name for the plug-in to start the test.');
	process.exit();
}

// Get the folder name of the plug-in to test

const folder = args[0];
const name = folder.startsWith('__') ? folder.substr(2) : folder; // Remove __ from front of example folders

// Look for the plug-in folder with the given name in the 'plugins' folder.
process.stdout.write(`\nSearching 'plugins' folder for sub folder '${folder}'... `);
const folders = fs.readdirSync(PLUGINS_DIR, {withFileTypes: true})
	.filter(f => f.isDirectory())
	.map(f => f.name)
	.filter(f => f == folder);

if (!Array.isArray(folders) || !folders.length) {
	console.log('and could not find it.\n    Folder names are case sensitive.');
	console.log('	For example, your plug-in folder structure should be like this:');
	console.log('		'+folder);
	console.log('		|__ '+name+'.js');
	process.exit();
}

console.log('found.');

// Look for the plug-in icon with the given name in the 'plugins/pluginname' folder.
process.stdout.write(`\nSearching 'plugins/${folder}' folder for icon file '${name}.ico'... `);
const icon_files = fs.readdirSync(`${PLUGINS_DIR}/${folder}/`)
	.filter(f => f == name+'.ico');

if (!Array.isArray(icon_files) || !icon_files.length) {
	console.log('and could not find it.\n    Icon names are case sensitive.');
	console.log('	Ensure that the icon file is in a folder with identical naming.');
	console.log('	For example, your folder structure should be like this:');
	console.log('		'+folder);
	console.log('		|__ '+name+'.js');
	console.log('		|__ '+name+'.ico');
	process.exit();
}

console.log('found.');

// Look for the plug-in js file with the given name in the 'plugins/pluginname' folder.
process.stdout.write(`\nSearching 'plugins/${folder}' folder for markdown file '${name}.md'... `);
const md_files = fs.readdirSync(`${PLUGINS_DIR}/${folder}/`)
	.filter(f => f == name+'.md');

if (!Array.isArray(md_files) || !md_files.length) {
	console.log('and could not find it.\n    Markdown file names are case sensitive.');
	console.log('	Ensure that the md file is in a folder with identical naming.');
	console.log('	For example, your folder structure should be like this:');
	console.log('		' + folder);
	console.log('		|__ '+folder+'.js');
	console.log('		|__ '+folder+'.md');
	console.log('		|__ '+folder+'.ico');
	process.exit();
}

console.log('found.');

// Look for the plug-in js file with the given name in the 'plugins/pluginname' folder.
process.stdout.write(`\nSearching 'plugins/${folder}' folder for code file '${name}.js'... `);
const js_files = fs.readdirSync(`${PLUGINS_DIR}/${folder}/`)
	.filter(f => f == name+'.js');

if (!Array.isArray(js_files) || !js_files.length) {
	console.log('and could not find it.\n    Javascript file names are case sensitive.');
	console.log('	Ensure that the js file is in a folder with identical naming.');
	console.log('	For example, your folder structure should be like this:');
	console.log('		'+folder);
	console.log('		|__ '+name+'.js');
	console.log('		|__ '+name+'.md');
	console.log('		|__ '+name+'.ico');
	process.exit();
}

console.log('found.');

// Helper function used when an error gets thrown
const _fail_and_exit_ = e => {
	if (e) { 
		console.log('and failed.');
		console.error(e);
		process.exit(42);
	}
};

// Copy the setting YAML file to the ./resources/Assets/plugin_yaml/ folder
// It is most probably required by the plugin's constructor when we try 
// to create an instance of the plugin
const settings_def_yaml = `${PLUGINS_DIR}/${folder}/${name}.yaml`
if (fs.existsSync(settings_def_yaml)) {
	process.stdout.write(`\nCopying YAML settings definition '${settings_def_yaml}' to 'resources' folder... `);
	fs.copyFile(settings_def_yaml, `./resources/Assets/plugin_yaml/${name}.yaml`, _fail_and_exit_);
	console.log('done.');
}

// Create storage folder
if (!fs.existsSync("./storage/")) {	
	fs.mkdirSync("./storage/");
}

// Create etc folder and dhcpcd.conf file
if (!fs.existsSync("./etc/dhcpcd.conf")) {
	process.stdout.write('\nCreating temporary dhcpcd.conf file... ');
	fs.mkdirSync("./etc/");
	const content = "interface eth0\n"+
					"static ip_address=0.0.0.0/24\n"+
					"static routers=192.168.0.1\n"+
					"static domain_name_servers=192.168.0.1\n\n"+
					"interface wlan0\n"+
					"static ip_address=0.0.0.0/24\n"+
					"static routers=192.168.0.1\n"+
					"static domain_name_servers=192.168.0.1\n";
	fs.writeFileSync("./etc/dhcpcd.conf", content, _fail_and_exit_);
	console.log('done.');
}

// Check whether module.exports is used in the plug-in js file with the given name in t.he 'plugins/pluginname' folder.
process.stdout.write(`\nAttempting to load exported 'PlugIn' from 'plugins/${folder}/${name}.js'... `);
const exported = require(`./${PLUGINS_DIR}/${folder}/${name}.js`);
const exported_keys = Object.keys(exported);

if (!exported_keys || !exported_keys.includes('PlugIn')) {
	console.log('and failed.');
	console.log("    Ensure that the plug-in class is exported as 'PlugIn' (case sensitive):");
	console.log('        module.exports = { PlugIn: xxx } // Where xxx is the name of your plug-in class');
	process.exit();
}

console.log('loaded.', exported);

const plugin = exported.PlugIn;
const class_name = plugin.prototype.constructor.name;

// Check whether the plug-in class can be instantiated
const make_x = () => {
	try {
		process.stdout.write(`\nCreating an instance of [${class_name}]... `);
		return new plugin({ flowindex: 0 });
	} catch (e) {
		console.log('and failed.');
		console.log("    Ensure that the plug-in class constructor accepts the parameter 'initialstate':");
		console.log('       constructor(initialstate) {');
		console.log('           super(initialstate);');
		console.log('       }');
		console.error(e)
		process.exit();
	}
}
const x = make_x();

console.log('done.');

// Check if plugin has a getName() function
try {
	process.stdout.write(`\nGetting the display name of [${class_name}]... `);
	console.log(`found '${plugin.getName()}'.`);

} catch (e) {
	console.log('and could not find it.');
	console.log('    Ensure that the plug-in class has a static getName() function:');
	console.log('        static getName() { return xxx } // Where xxx is the display name of your plug-in');
	process.exit();
}

// check if plugin inherit form correct plugin base
const _inherits_ = base_type => {
	process.stdout.write(`\nChecking that [${class_name}] inherits [${base_type.prototype.constructor.name}]... `);
	if (!base_type.isPrototypeOf(plugin)) {
		console.log('negative.');
		console.log("    Ensure that the plug-in class inherits one of the base classes from 'plugin_sdk.js':");
		console.log("        const BoardAvailableBase = require('../../plugin_sdk.js').PlugInBoardAvailableBase;");
		console.log('        class xxx extends BoardAvailableBase // Where xxx is the name of your plug-in class');
		process.exit();
	}
	// if plugin belong to _MR_ plugin type, check if it is inherit PlugInMachineReadyBase class
	console.log('affirmative.');
}

// Declare the delegate that will look for the function with the given
// name, invoke it with the given parameters and check the 
// correctness of its return type
const _probe_ = (fx_name, expected_return_type, ...params) => {
	process.stdout.write(`Calling ${fx_name}()... `);
	try {
		const fx = x[fx_name];
		if (fx === undefined) {
			console.log('FAILED: Method not found.');
			return;
		}
		const val = fx.apply(x, params);
		if (expected_return_type === undefined || expected_return_type === null) {
			console.log('OK.')
		} else if (val === undefined) {
			console.log('FAILED: Expecting return of ', expected_return_type, 'but got none.')
		} else if (typeof val === expected_return_type) {
			console.log("OK. Returned '" + val + "'.");
		} else {
			console.log('FAILED: Expecting return of', expected_return_type, 'but got', typeof val, 'instead.');
		}
	} catch (e) {
		console.log(e);
	}
}

switch (x.pluginType) {
	case _PLUGINTYPE_._BA_:
		_inherits_(BoardAvailableBase);
		_probe_('getBA', 'boolean');		
		break;

	case _PLUGINTYPE_._MR_:
		_inherits_(MachineReadyBase);
		_probe_('getMR', 'boolean');
		break;

	case _PLUGINTYPE_._VAL_:
		_inherits_(ValidationBase);
		_probe_('setMode', null, 'SCAN');
		_probe_('setSerials', null); // Testing for no-scan mode
		_probe_('setSerials', null, 'AAABBBCCCC', undefined, Date.now, undefined); // Testing for top
		_probe_('setSerials', null, undefined, '0123456789', undefined, Date.now); // Testing for bottom
		_probe_('setSerials', null, 'AAABBBCCCC', '0123456789', Date.now, Date.now); // Testing for both
		_probe_('getOK', 'boolean');
		_probe_('abort');
		_probe_('done');
		break;

	default:
		console.log('The type of the plug-in could not be determined.');
		console.log("    Ensure that the plug-in class inherits one of the base classes from 'plugin_sdk.js':");
		break;
}

// Check if common method return correctly for all type of plugin
_probe_('syncConfig');
_probe_('getInfo', 'string');
_probe_('getReady', 'boolean');
// Always call dispose last
_probe_('dispose');

// Remove YAML config file
fs.unlinkSync(`./resources/Assets/plugin_yaml/${name}.yaml`);

// If testing on Windows, remove the created directories
const rm_dir_cmd = os.platform() === 'win32' ? 'rmdir /s /q' : 'rm -rf';
const _remove_dir_ = dir => {
	process.stdout.write(`Removing temp direcotry '${dir}'... `);
	execSync(`${rm_dir_cmd} "${dir}"`, e => {
		console.log('and failed.');
		console.error(e);
	});
	console.log('done.');
};

_remove_dir_('./storage/');
_remove_dir_('./etc/');

console.log('\nScanning complete.\n');
