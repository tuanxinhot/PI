#!/usr/bin/node
'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2016-2020 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const SysConfig = require('./config.system');
const Config = require('./config.js');
const Utils = require('./utils.js');
const FlowCollector = require('./flow_collector.js');
const Log = require('./log.js');
const HttpInterface = require('./http_interface.js');
const fs = require('fs');
const execSync = require('child_process').execSync;
const PlugInConfig = require('./plugin_config.js');
const plugin = require('../../plugin_sdk.js');
const Sdk = plugin.Sdk;
const AppVersion = Config.getVersion();

console.log(' ╓─────────────────────────────────────────╖');
console.log(' ║   PICO getting ready to kick butt...    ║');
console.log(' ╙─────────────────────────────────────────╜');

console.log(`PICO Version: ${AppVersion.verNumber}-${AppVersion.verBuild}-${AppVersion.verText}.${AppVersion.verRev}`);

SysConfig.load();

// Validate the config file. The file will be created if it does not exists
Config.validate();

// Check that the dhcpcd.conf monitoring service is registered and started
// This service checks for when the dhcpcd.conf is updated, i.e. when the user
// sets a new static IP, and then restarts the dhcpcd, docker and docker-compose
// services (refer to rdhcp.sh)
const COPY_FROM_RESTARTDHCP = 'sudo cp /restartdhcp/';
const SYSTEM_DIR = '/etc/systemd/system/';
// Copy over the script file that the service triggers
// We always copy this file over just in case there are updates to it
console.log('Copying rdhcp.sh to /scripts/ folder.')
execSync(COPY_FROM_RESTARTDHCP + 'rdhcp.sh /scripts/');
// Get the status of the service
const dhcp_monitor = Utils.getDhcpMonitorStatus();
if (!dhcp_monitor.enabled) {
	// The service has not been registered, register it
	// But first, we copy over the service files if they don't exist
	if (!fs.existsSync(SYSTEM_DIR + 'restart-dhcpcd.path')) {
		console.log('Copying restart-dhcpcd.path to ' + SYSTEM_DIR + ' folder.');
		execSync(COPY_FROM_RESTARTDHCP + 'restart-dhcpcd.path ' + SYSTEM_DIR);
	}
	if (!fs.existsSync(SYSTEM_DIR + 'restart-dhcpcd.service')) {
		console.log('Copying restart-dhcpcd.service to ' + SYSTEM_DIR + ' folder.');
		execSync(COPY_FROM_RESTARTDHCP + 'restart-dhcpcd.service ' + SYSTEM_DIR)
	}
	console.log('Registering service to monitor dhcpcd.conf.');
	try {
		execSync('sudo systemctl enable restart-dhcpcd.path');		
	} catch (e) {
		console.log(e);
	}
}
if (!dhcp_monitor.started) {
	// The service has been registered but not started, start it
	console.log('Starting service to monitor dhcpcd.conf.');
	try {
		execSync('sudo systemctl start restart-dhcpcd.path');
	} catch (e) {
		console.log(e);
	}
}

const flows = new FlowCollector();

// assign eth0 to MES if eth0 is configured and mes network_interface equal to null
const MESconfig = PlugInConfig.getConfig('MES', 0)
if (Sdk.getStaticIp('eth0') && !MESconfig.network_interface) {
	MESconfig.network_interface = 'eth0'
	PlugInConfig.setConfig('MES', 0, MESconfig)
	flows.syncPluginConfig('MES', 0);

}
// Starts up the web server which serves requests made by the UI in the WebKiosk container
// Any variable declaration for state must be done before this statement!
const httpServer = new HttpInterface(flows);

// Declare the global error handler which will restart Docker on any uncaught errors
process.on('uncaughtException', (err) => {
	console.log('Unhandled error caught.');
	console.error(err);
});

process.on('SIGTERM', () => {
	console.log('SIGTERM received. Turning off BAout and MRout...');
	httpServer.turnOffAllOutputs();
	process.exit(0);
});

process.on('SIGINT', () => {
	console.log('SIGINT received. Turning off BAout and MRout...');
	httpServer.turnOffAllOutputs();
	process.exit(0);
});

// Start log dumping to the central cloud database
const log = new Log();
