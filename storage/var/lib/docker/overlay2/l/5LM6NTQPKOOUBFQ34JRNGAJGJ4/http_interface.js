'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2016-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const http = require('http');
const HttpDispatcher = require('httpdispatcher');
const Config = require('./config.js')
const Utils = require('./utils.js');
//const execSync = require('child_process').execSync;
const spawn = require('child_process').spawn;
const PlugIns = require('./plugin_collector.js');
const PlugInConfig = require('./plugin_config.js');
const PlugInConfigUi = require('./plugin_config_ui.js');
const readFileFunc = require('./read_file_lib.js');
const Dns = require('dns')
const os = require('os');

const DEF_PORT = 80;
const fs = require('fs');
const container_id = fs.readFileSync('/proc/self/cgroup', 'utf8').split('\n')[0].split('/')[2]
const LOG_DIR = '/log/' + container_id + '/';
const LOG_FILE = container_id + '-json.log';
const LOG_PATH = LOG_DIR + LOG_FILE;
const HOST_COMPOSE_FILE = '/compose.yml'
const CONTAINER_COMPOSE_FILE = '/docker-compose.yml'


class HttpStatusInterface {

	/** Creating variables to help create the web page **/
	constructor(flows) {
		const self = this;
		this.debug = false;
		this.flows = flows;
		this.dispatcher = new HttpDispatcher();

		function handleRequest(request, response) {
			try {
				self.dispatcher.dispatch(request, response);
			} catch (err) {
				console.error(err);
			}
		}

		// Check for compose update:
		// Check for internet connection first, if there is a connection, query system container to
		// check for compomse file update, 
		this.has_compose_updates = false;
		const check_connection = async () => {
			Dns.resolve('www.docker.corp.jabil.org', err => {
				if (err) {
					console.log("No connection.");
					return false
				} else {
					console.log("Connected to network.");
					return true
				}
			})
		};
		// Download compose file and save into file compose.yml
		const check_compose = async () => {
			let url = 'http://172.17.0.1:3000/api/v1.0/sysconf/compose'
			const query_compose = async () => {
				console.log('Querying system container for compose file updates.')
				let res = await Utils.httpGet(url);
				if (!res.ok) {
					url = 'http://127.0.0.1:3000/api/v1.0/sysconf/compose'
					res = await Utils.httpGet(url);
				}
				if (res.ok) {
					return res.data;
				}
				console.log('No valid reply when querying system container.');
				if (res.error) {
					console.error(res.error);
				}
				return null;
			}
			let compose_response = await query_compose();
			// Write the content of API return value to compose.yml
			fs.writeFileSync('compose.yml', compose_response, function (err) {
				if (err) throw err;
			});

			// Compare the compose file from host (compose.yml) with the on in the image (docker-compose.yml)
			const host_compose = fs.readFileSync(HOST_COMPOSE_FILE);
			const container_compose = fs.readFileSync(CONTAINER_COMPOSE_FILE);
			// If host compose file different from docker-compose.yml, update Host compose file.
			if (!host_compose.equals(container_compose)) {
				fs.copyFileSync(CONTAINER_COMPOSE_FILE, HOST_COMPOSE_FILE)
				console.log('There were updates to compose.yml.')
				let upload_compose = await Utils.httpUpload(url, HOST_COMPOSE_FILE);
				if (upload_compose.ok) {
					console.log('Updated compose file to host. ');
					this.has_compose_updates = true;
					return
				}
				if (upload_compose.error) {
					console.log('Error while uploading compose file.');
					console.error(upload_compose.error);
				} else {
					console.log(`Uploading compose file met ${upload_compose.response.statusCode} ${upload_compose.response.statusMessage}.`);
				}
			} else {
				console.log('Compose file checked. /boot/compose.yml same as in-image docker-compose.yml, no overwrite action.');
			}
		}
		setTimeout(() => {
			let retry_count = 0;
			do {
				if (check_connection()) {
					try {
						check_compose()
					} catch (err) { console.log(err) }
					break
				}
				// Retry 3 times， break while loop if there is connection
				retry_count++;
			} while (retry_count < 3);
		}, 20000);
		// Check for new image/OS update
		this.has_sys_updates = false;
		this.check_for_updates_timer = setInterval(async () => {
			const query_system_container = async () => {
				console.log('Querying system container for Docker image and system updates.')
				let res = await Utils.httpGet('http://172.17.0.1:3000/api/v1.0/system/request-restart');
				if (!res.ok) {
					res = await Utils.httpGet('http://127.0.0.1:3000/api/v1.0/system/request-restart');
				}
				if (res.ok) {
					return JSON.parse(res.data);
				}
				console.log('No valid reply when querying system container.');
				if (res.error) {
					console.error(res.error);
				}
				return null;
			}
			let system_response = await query_system_container();
			// If there was no valid response then try again
			if (!system_response) {
				system_response = await query_system_container();
				if (!system_response) {
					return;
				}
			}

			if (!Array.isArray(system_response)) {
				console.log('Did not get expected query response from system container.');
				return;
			}

			system_response.forEach((item => {
				const reason = item.reason;
				if (reason.includes('Downloaded newer image for') || reason.includes('restart')) {
					console.log('Reboot required. Reason: ' + reason);
					this.has_sys_updates = true;
					clearInterval(this.check_for_updates_timer);
				}
			}))
		}, 12 * 60 * 60 * 1000); //12hour 12 * 60 * 60 * 1000 120000

		//Network Diagnosis
		//get Network Interface and IP
		this.dispatcher.onGet('/getNetworkInterface', async (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });

			let respond = await Utils.httpGet('http://172.17.0.1:3000/api/v1.0/system/network/interfaces');

			if (respond.ok) {
				res.end(JSON.stringify(JSON.parse(respond.data)));	
			} else {
				res.end(JSON.stringify(false));
			}
		});

		//Network Diagnosis
		//get hostname
		this.dispatcher.onGet('/getHostname', async (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });

			var hostname = await os.hostname();
			
			res.end(JSON.stringify(hostname));

		});

		//Network Diagnosis
		//get DNS
		this.dispatcher.onGet('/getNameservers', async (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });

			let respond = await Utils.httpGet('http://172.17.0.1:3000/api/v1.0/system/network/nameservers');

			if (respond.ok) {
				res.end(JSON.stringify(JSON.parse(respond.data)));	
			} else {
				res.end(JSON.stringify(false));
			}
		});

		//Network Diagnosis
		//resolve DNS
		this.dispatcher.onGet('/resolveDNS', async (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });

			const obj = JSON.parse(JSON.stringify(req.params));
			var url = 'http://172.17.0.1:3000/api/v1.0/system/network/interfaces/' + obj.interface + '/nameservers/' + obj.dnsvalue + '/resolve?address=myjabil.corp.jabil.org';
			let respond = await Utils.httpPost_noBody(url);
			const result = JSON.parse(respond.data);
			if (respond.ok) {
				if(result.length > 0){
					console.log("[NetDiag] - Resolving myjabil.corp.jabil.org using " + obj.interface + ": " + obj.dnsvalue + " - Passed");
					res.end(JSON.stringify(true));		
				} else {
					console.log("[NetDiag] - Resolving myjabil.corp.jabil.org using " + obj.interface + ": " + obj.dnsvalue + " - Failed");
					res.end(JSON.stringify(false));
				}
			} else {
				console.log("[NetDiag] - Resolving myjabil.corp.jabil.org using " + obj.interface + ": " + obj.dnsvalue + " - Failed");
				res.end(JSON.stringify(false));
			}
		});

		//Network Diagnosis
		//check application service availability
		this.dispatcher.onGet('/applicationService', async (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });

			const obj = JSON.parse(JSON.stringify(req.params));
			var url = 'http://172.17.0.1:3000/api/v1.0/system/network/interfaces/' + obj.interface + '/request?url=https%3A%2F%2Fdocker.corp.jabil.org';
			let respond = await Utils.httpPost_noBody(url);
			const result = JSON.parse(respond.data);

			if (respond.ok) {
				if(result.length > 0){
					if(result[0].status_code != null){
						console.log("[NetDiag] - Checking Application Service using " + obj.interface + " - Passed");
						res.end(JSON.stringify(true));
					} else {
						console.log("[NetDiag] - Checking Application Service using " + obj.interface + " - Failed");
						res.end(JSON.stringify(false));
					}			
				} else {
					console.log("[NetDiag] - Checking Application Service using " + obj.interface + " - Failed");
					res.end(JSON.stringify(false));
				}
			} else {
				console.log("[NetDiag] - Checking Application Service using " + obj.interface + " - Failed");
				res.end(JSON.stringify(false));
			}
		});

		//Network Diagnosis
		//check os update service availability
		this.dispatcher.onGet('/OSUpdateService', async (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });

			const obj = JSON.parse(JSON.stringify(req.params));

			var url_pilogin = 'http://172.17.0.1:3000/api/v1.0/system/network/interfaces/' + obj.interface + '/request?url=http%3A%2F%2Fpi%2Dlogin.docker.corp.jabil.org';
			let respond_pilogin = await Utils.httpPost_noBody(url_pilogin);
			const result_pilogin = JSON.parse(respond_pilogin.data);

			var url_piupdate = 'http://172.17.0.1:3000/api/v1.0/system/network/interfaces/' + obj.interface + '/request?url=http%3A%2F%2Fpi%2Dupdate.docker.corp.jabil.org';
			let respond_piupdate = await Utils.httpPost_noBody(url_piupdate);
			const result_piupdate = JSON.parse(respond_piupdate.data);

			var service_availability = {};
			service_availability.pi_login = false;
			service_availability.pi_update = false;

			if (respond_pilogin.ok) {
				if(result_pilogin.length > 0){
					if(result_pilogin[0].status_code != null){
						console.log("[NetDiag] - Checking OS Update Service(Pi-login) using " + obj.interface + " - Passed");
						service_availability.pi_login = true;
					} else {
						console.log("[NetDiag] - Checking OS Update Service(Pi-login) using " + obj.interface + " - Failed");
					} 		
				} else {
					console.log("[NetDiag] - Checking OS Update Service(Pi-login) using " + obj.interface + " - Failed");
				}
			} else {
				console.log("[NetDiag] - Checking OS Update Service(Pi-login) using " + obj.interface + " - Failed");
			}

			if (respond_piupdate.ok) {
				if(result_piupdate.length > 0){
					if(result_piupdate[0].status_code != null){
						console.log("[NetDiag] - Checking OS Update Service(Pi-update) using " + obj.interface + " - Passed");
						service_availability.pi_update = true;
					} else {
						console.log("[NetDiag] - Checking OS Update Service(Pi-update) using " + obj.interface + " - Failed");
					}		
				} else {
					console.log("[NetDiag] - Checking OS Update Service(Pi-update) using " + obj.interface + " - Failed");
				}
			} else {
				console.log("[NetDiag] - Checking OS Update Service(Pi-update) using " + obj.interface + " - Failed");
			}

			res.end(JSON.stringify(service_availability));

		});
	
		// Sets a folder directory (since we call it in 'main.js', the home directory is where 'main.js' is in)
		this.dispatcher.setStatic('/resources');
		this.dispatcher.setStaticDirname('resources');

		// Reroutes users automatically to resources/index.html when calling the root
		this.dispatcher.onGet('/', (req, res) => {
			res.writeHead(302, { 'Location': '/resources/index.html' });
			res.end('');
		});

		this.dispatcher.onGet('/appVersion', (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify(Config.getVersion()));
		});

		// Returns all state for display
		this.dispatcher.onGet('/state', (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });
			// return system update and state of each flow
			res.end(JSON.stringify({ 'has_updates': this.has_sys_updates, 'flows': this.flows.getState() }));
		});

		this.dispatcher.onPost('/resumescan', (req, res) => {
			this.flows.setResumeScanTrue();
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end();
		});

		// Returns the available plugins' name and if they are enabled
		this.dispatcher.onGet('/getPlugins', (req, res) => {
			const index = req.params.flowindex;
			//const loaded = this.flows.getFlow(index).getLoadedPlugIns();
			const cfg = Config.retrieve().Flows[index];
			let loaded = cfg.PlugIns
			const available = PlugIns.getAvailablePlugins()
				.filter(lib => lib.PlugIn.getName() !== 'MES Emulator')
				.map(lib => {
					const name = lib.PlugIn.getName();
					return { Name: name, Enabled: loaded.includes(name) }
				});
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({
				'available': available,
				'debug': this.debug
			}));
		});

		// Returns the debug state
		this.dispatcher.onGet('/debug', (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'devMode': this.debug ? 'Debug00' : 'Normal' }));
		});

		// Returns the IP address of the host the container is running on
		this.dispatcher.onGet('/status', async (req, res) => {
			let ip = await Utils.getCurrentIp();
			if (!ip) { ip = 'No network or IP' }
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'ip': ip }));
		});

		// Returns the Settings html of the requested plugin
		this.dispatcher.onGet('/pluginSettings', (req, res) => {
			const html = PlugInConfigUi.getHtml(req.params.pluginName, req.params.flowindex);
			// TODO: This part isn't right and needs more discussion
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'result': html }));
		})

		// Updates the plugin setting config file
		this.dispatcher.onPost('/pluginUpdateSettings', (req, res) => {
			const name = req.params.pluginName;
			const index = req.params.flowindex;
			const pluginSettings = JSON.parse(req.params.pluginSettings)
			// get detail from yaml config file
			const yamlconfig = PlugInConfig.getWholeYamlConfig(name)
			// Datatype check
			const DatatypeCheck = (datavalue, datatype) => {
				switch (datatype) {
					case 'int':
						datavalue = datavalue * 1
						if (!Number.isInteger(datavalue)) {
							return false
						}
						break;
					case 'decimal':
						datavalue = parseFloat(datavalue)
						// if not isNaN return true if datavalue is a valid number
						if (isNaN(datavalue)) {
							return false
						}
						break;
					case 'bool':
						if (typeof (datavalue) !== 'boolean') {
							return false
						}
						break;
					case 'string':
						if (typeof (datavalue) !== datatype) {
							return false
						}
						break;
					case 'date':
						//2020-12-31
						const regex_date = /(([1][0-2]|[0][0-9])-([0-2][0-9]|[3][0-1])-[1-9]([0-9]{3}))|([1-9]([0-9]{3})-([1][0-2]|[0][0-9])-([0-2][0-9]|[3][0-1]))/
						if (!regex_date.test(datavalue)) {
							return false
						}
						break;
					case 'datetime':
						//2021-01-13 16:38
						const regex_datetime = /[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[1-2][0-9]|3[0-1]) (2[0-3]|[01][0-9]):[0-5][0-9]/;
						if (!regex_datetime.test(datavalue)) {
							return false
						}
						break;
					case 'time':
						//11:04
						const regex_time = /^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/
						if (!regex_time.test(datavalue)) {
							return false
						}
						break;
				}
				return true
			}
			// Data range check
			const RangeCheck = (datavalue, min, max) => {
				if (min) {
					if (datavalue < min) {
						return false
					}
				}
				if (max) {
					if (datavalue > max) {
						return false
					}
				}
				return true
			}
			// Data length check
			const LengthCheck = (datavalue, min_length, max_length) => {
				if (min_length) {
					if (datavalue.length < min_length) {
						return false
					}
				}
				if (max_length) {
					if (datavalue.length > max_length) {
						return false
					}
				}
				return true
			}
			const pluginSettings_config = {};
			var error_msg = '';
			for (let item in pluginSettings) {
				// item = 'temp'
				// pluginSettings[item] =  {'val': '30', 'data_type':'int'}
				var datavalue = pluginSettings[item].val;
				// Get data information from plugin yaml file
				const datatype = yamlconfig[item]['datatype']
				const min = 'min' in yamlconfig[item] ? yamlconfig[item]['min'] : null;
				const max = 'max' in yamlconfig[item] ? yamlconfig[item]['max'] : null;
				const min_length = 'min_length' in yamlconfig[item] ? yamlconfig[item]['min_length'] : null;
				const max_length = 'max_length' in yamlconfig[item] ? yamlconfig[item]['max_length'] : null;
				if (datatype == 'bool') {
					// convert string data value '1' and '0' to boolean
					datavalue = (datavalue === '1');
				}
				// Check Data type of input data
				if (!DatatypeCheck(datavalue, datatype)) {
					error_msg = error_msg.concat('Wrong data type! Data inserted "' + datavalue + '" is not ' + datatype + '.')
					console.log(error_msg)
				}
				// Check if input data is within the range
				if (!RangeCheck(datavalue, min, max)) {
					error_msg = error_msg.concat('\nData inserted "' + datavalue + '" is out of range!')
					error_msg = min ? error_msg + ' Value enter must be more than or equal to ' + min + '.' : error_msg
					error_msg = max ? error_msg + ' Value enter must be less than or equal to ' + max + '.' : error_msg
					console.log(error_msg)
				}
				// Check max and min length of input data
				if (!LengthCheck(datavalue, min_length, max_length)) {
					error_msg = error_msg.concat('\nData length inserted "' + datavalue + '" is out of range!')
					error_msg = min_length ? error_msg + ' Input length must be more than or equal to ' + min_length + '.' : error_msg
					error_msg = max_length ? error_msg + ' Input length must be less than or equal to ' + max_length + '.' : error_msg
					console.log(error_msg)
				}
				// retrun error of error_msg is not empty
				if (error_msg) {
					res.writeHead(400);
					res.end(error_msg);
					return
				}

				// Append the value to be written info config file if all item check pass
				pluginSettings_config[item] = datavalue
			}
			PlugInConfig.setConfig(name, index, pluginSettings_config);
			// Sync the configuration settings with the actual plugin instance
			this.flows.syncPluginConfig(name, index);
			res.writeHead(200);
			res.end('');
		})

		// Returns PlugInConfig.getWholeYamlConfig(pluginName)
		this.dispatcher.onGet('/getWholeYamlConfig', (req, res) => {
			const pluginName = req.params.pluginName;
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify(PlugInConfig.getWholeYamlConfig(pluginName)));
		});

		// Check if the plugin is enable/disable from the UI (checkbox).
		//     If enabled, then check whether it is already inside the config file.
		//           If it's not, adds it in. Else, do nothing. Vice-versa for disabled.
		this.dispatcher.onPost('/pluginUpdate', (req, res) => {
			// newest changes: to update all plugins at once instead of every single plugin from frontend loop
			if (req.params.pluginsdata != undefined) {
				const index = req.params.flowindex;
				const flow = this.flows.getFlow(index);
				const pluginsData = JSON.parse(req.params.pluginsdata);
				let loaded = null
				// Get list of flow plugin from config file when it is not enabled
				if (flow === undefined) {
					loaded = Config.retrieve().Flows[index].PlugIns;
					// Get list of flow collector if it is enabled
				} else {
					loaded = flow.getLoadedPlugIns();
				}

				// iterate each of the plugins
				pluginsData.forEach((pluginData) => {
					if (pluginData.check) {
						if (!loaded.includes(pluginData.name)) { loaded.push(pluginData.name); }
					} else {
						if (loaded.includes(pluginData.name)) { loaded = loaded.filter(p => p !== pluginData.name); }
					}
				});

				if (this.debug) {
					const cfg = Config.retrieve().Flows[index].PlugIns;
					const new_cfg = []
					cfg.forEach(p => { if (loaded.includes(p) || p == 'MES') new_cfg.push(p); })
					loaded.forEach(p => { if (!new_cfg.includes(p) && p !== 'MES Emulator') new_cfg.push(p); })
					Config.update(c => c.Flows[index].PlugIns = new_cfg);

					if (loaded.includes('MES')) { loaded = loaded.filter(p => p !== 'MES'); }
					if (!loaded.includes('MES Emulator')) { loaded.push('MES Emulator'); }
				} else {
					if (loaded.includes('MES Emulator')) { loaded = loaded.filter(p => p !== 'MES Emulator'); }
					if (loaded.length == 0) { loaded.push('MES'); }
					Config.update(c => c.Flows[index].PlugIns = loaded);
				}

				if (flow) {
					// This part checks and compares the original loaded plugins with the manipulated plugin array
					// If it is the same, skips the load step
					const original = flow.getLoadedPlugIns()
					if ((original.length === loaded.length) && original.every((ele, i) => ele === loaded[i])) {
						console.log(`Plugins for flow ${index + 1} already loaded, skipping load step.`);
					} else {
						// There are plugins that are not yet loaded, proceed to load them
						flow.loadPlugIns(loaded);
					}
				}
			}

			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'debug': this.debug ? 'Debug00' : 'Normal' }));
		});

		// Verifies the given password
		this.dispatcher.onPost('/key', (req, res) => {
			let password = req.params.key.valueOf().trim();
			let result = false;
			if (Config.verifyPassword(password)) {
				result = true;
			}
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'result': result }));
		});

		// Handles changing the password
		this.dispatcher.onPost('/keyChange', (req, res) => {
			let passwordOld = req.params.oldkey.valueOf().trim();
			let result = false;
			if (Config.verifyPassword(passwordOld)) {
				let passwordNew = req.params.newkey.valueOf().trim();
				passwordNew = Config.hashSha256(passwordNew);
				Config.update(cfg => cfg.PasswordHash = passwordNew);
				console.log(`INFO: Setting Password changed - from ip: ${req.connection.remoteAddress}`);
				result = true;
			}
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'result': result }));
		});

		// Verifies the given Admin password
		this.dispatcher.onPost('/adminKey', (req, res) => {
			let password = req.params.key.valueOf().trim();
			let result = false;
			if (Config.verifyAdminPassword(password)) {
				result = true;
			}
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'result': result }));
		});

		// Handles changing the Admin password
		this.dispatcher.onPost('/adminKeyChange', (req, res) => {
			let passwordOld = req.params.oldkey.valueOf().trim();
			let result = false;
			if (Config.verifyAdminPassword(passwordOld)) {
				let passwordNew = req.params.newkey.valueOf().trim();
				passwordNew = Config.hashSha256(passwordNew);
				// enforcement rule on the passwords: bypassPassword cannot be the same as configPassword
				// check if newBypassPassword same as configPassword before changing the bypassPassword
				if (Config.retrieve().PasswordHash === passwordNew) {
					console.log('New Admin Password same as Setting Password.');
					result = "BothPasswordSame";
				} else {
					Config.update(cfg => cfg.AdminPasswordHash = passwordNew);
					console.log(`INFO: Admin Password changed - from ip: ${req.connection.remoteAddress}`);
					result = "AdminPasswordUpdated";
				}
			}
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'result': result }));
		});

		this.dispatcher.onGet('/cfg', (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify(Config.retrieve()));
		});

		this.dispatcher.onPost('/cfg', (req, res) => {
			console.log(`INFO: Update Configuration - from ip: ${req.connection.remoteAddress}`);
			const _log_ = (flow, prop, val) => { console.log(`CFG:F ${flow}: ${prop} =  ${val}`); };
			Config.update(cfg => {
				const p = req.params;
				const flowcount = p.flowcount;
				if (cfg.FlowCount !== flowcount) { cfg.FlowCount = flowcount; _log_('Î£', 'FlowCount', flowcount); }

				const cf1 = cfg.Flows[0];
				const mode1 = p['f1[mode]'];
				if (cf1.Mode !== mode1) { cf1.Mode = mode1; _log_(1, 'Mode', mode1); }
				const prefix1 = p['f1[prefix]'].valueOf().trim();
				if (cf1.BarcodePrefix !== prefix1) { cf1.BarcodePrefix = prefix1; _log_(1, 'BarcodePrefix', prefix1 || '<nil>'); }
				const suffix1 = p['f1[suffix]'].valueOf().trim();
				if (cf1.BarcodeSuffix !== suffix1) { cf1.BarcodeSuffix = suffix1; _log_(1, 'BarcodeSuffix', suffix1 || '<nil>'); }
				const validationTrigger1 = p['f1[validationTrigger]'].valueOf().trim();
				if (cf1.ValidationTrigger !== validationTrigger1) { cf1.ValidationTrigger = validationTrigger1; _log_(1, 'ValidationTrigger', validationTrigger1 || '<nil>'); }
				const rescanTimeout1 = parseFloat(p['f1[rescanTimeout]']);
				if (cf1.RescanTimeout !== rescanTimeout1) { cf1.RescanTimeout = rescanTimeout1; _log_(1, 'RescanTimeout', rescanTimeout1 || '<nil>'); }
				const rescanLimit1 = parseInt(p['f1[rescanLimit]']);
				if (cf1.RescanLimit !== rescanLimit1) { cf1.RescanLimit = rescanLimit1; _log_(1, 'RescanLimit', rescanLimit1 || '<nil>'); }
				const triggerTime1 = parseFloat(p['f1[triggerTime]']);
				if (cf1.TriggerTime !== triggerTime1) { cf1.TriggerTime = triggerTime1; _log_(1, 'TriggerTime', triggerTime1 || '<nil>'); }

				const cf2 = cfg.Flows[1];
				const mode2 = p['f2[mode]'];
				if (cf2.Mode !== mode2) { cf2.Mode = mode2; _log_(2, 'Mode', mode2); }
				const prefix2 = p['f2[prefix]'].valueOf().trim();
				if (cf2.BarcodePrefix !== prefix2) { cf2.BarcodePrefix = prefix2; _log_(2, 'BarcodePrefix', prefix2 || '<nil>'); }
				const suffix2 = p['f2[suffix]'].valueOf().trim();
				if (cf2.BarcodeSuffix !== suffix2) { cf2.BarcodeSuffix = suffix2; _log_(2, 'BarcodeSuffix', suffix2 || '<nil>'); }
				const validationTrigger2 = p['f2[validationTrigger]'].valueOf().trim();
				if (cf2.ValidationTrigger !== validationTrigger2) { cf2.ValidationTrigger = validationTrigger2; _log_(2, 'ValidationTrigger', validationTrigger2 || '<nil>'); }
				const rescanTimeout2 = parseFloat(p['f2[rescanTimeout]']);
				if (cf2.RescanTimeout !== rescanTimeout2) { cf2.RescanTimeout = rescanTimeout2; _log_(2, 'RescanTimeout', rescanTimeout2 || '<nil>'); }
				const rescanLimit2 = parseInt(p['f2[rescanLimit]']);
				if (cf2.RescanLimit !== rescanLimit2) { cf2.RescanLimit = rescanLimit2; _log_(2, 'RescanLimit', rescanLimit2 || '<nil>'); }
				const triggerTime2 = parseFloat(p['f2[triggerTime]']);
				if (cf2.TriggerTime !== triggerTime2) { cf2.TriggerTime = triggerTime2; _log_(2, 'TriggerTime', triggerTime2 || '<nil>'); }

			});
			this.flows.sync();
			res.writeHead(200);
			res.end('');
		});

		// Handles changing the mode
		this.dispatcher.onPost('/mode', (req, res) => {
			console.log(`INFO: Attempt to change mode - from ip: ${req.connection.remoteAddress}`);
			let password = null;
			try{
				if(req.params.key){
					password = req.params.key.valueOf().trim();
				} else {
					console.log("INFO: Attempt to change mode - Password is empty");
					res.writeHead(401);
					res.end('Empty Password');
					return;
				}
				
			} catch(e){
				console.log("INFO: Attempt to change mode - Unable to retrieve password correctly");
				res.writeHead(401);
				res.end('Unable to retrieve password correctly');
				return;
			}
			
			let result = false;
			if (Config.verifyAdminPassword(password)) {
				result = true;
			} else {
				console.log("INFO: Attempt to change mode - Password is wrong");
				res.writeHead(401);
				res.end('Wrong Password');
				return;
			}
			
			const index = 0;
			const flow = this.flows.getFlow(index);
			// Check whether to update the current mode
			if (req.params.Mode) {
				const newMode = req.params.Mode;
				try{
					flow.setMode(newMode);
					Config.update(cfg => cfg.Flows[index].Mode = newMode);
					console.log('Mode for flow 0 updated to \'' + newMode + '\'.');
				} catch(e){
					console.log("INFO: Attempt to change mode - Incorrect Mode");
					res.writeHead(406);
					res.end('Incorrect Mode');
					return;
				}
				
			}
			res.writeHead(200);
			res.end("Change Mode Successfully");
		});

		// Handles changing the debug mode
		this.dispatcher.onPost('/debug', (req, res) => {
			console.log(`INFO: Normal/Debug mode changing - from ip: ${req.connection.remoteAddress}`);
			const devMode = req.params.devMode;
			this.debug = devMode == 'Debug00';
			console.log((this.debug ? 'Entering' : 'Exiting') + ' DEBUG mode.');
			for (let f of this.flows) {
				let loaded = f.getLoadedPlugIns();
				if (this.debug) {
					if (loaded.includes('MES')) { loaded = loaded.filter(p => p !== 'MES'); }
					if (!loaded.includes('MES Emulator')) { loaded.push('MES Emulator'); }
					f.addDummyScanner();
				} else {
					const config = Config.retrieve();
					if (loaded.includes('MES Emulator')) { loaded = loaded.filter(p => p !== 'MES Emulator'); }
					if ((loaded.length == 0) || (config.Flows[f.index].PlugIns.includes('MES'))) { loaded.push('MES'); }
					f.removeDummyScanner();
				}
				f.loadPlugIns(loaded);
			}
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify({ 'mode': this.debug ? 'Debug00' : 'Normal' }));
		});

		// Handles the power options
		this.dispatcher.onPost('/power', async (req, res) => {
			console.log(`INFO: Shutdown/Reboot/Restart Application - from ip: ${req.connection.remoteAddress}`);
			if(req.connection.remoteAddress != req.connection.localAddress){
				let password = null;
				try{
					if(req.params.key){
						password = req.params.key.valueOf().trim();
					} else {
						console.log("INFO: Attempt to Shutdown/Reboot/Restart Application - Password is empty");
						res.writeHead(401);
						res.end('Empty Password');
						return;
					}
				
				} catch(e){
					console.log("INFO: Attempt to Shutdown/Reboot/Restart Application - Unable to retrieve password correctly");
					res.writeHead(401);
					res.end('Unable to retrieve password correctly');
					return;
				}
			
				let result = false;
				if (Config.verifyAdminPassword(password)) {
					console.log("INFO: Attempt to Shutdown/Reboot/Restart Application - Password verification passed");
					result = true;
				} else {
					console.log("INFO: Attempt to Shutdown/Reboot/Restart Application - Password is wrong");
					res.writeHead(401);
					res.end('Wrong Password');
					return;
				}
			}

			// Sanitize the option
			const option = req.params.option;
			//Switched the logic below from an 'OR' to 'AND' operator, so that it will shutdown only when both conditions are met.
			if (option != 'reboot' && option != 'shutdown' && option != 'restart application') {
				res.writeHead(400);
				res.end('');
				return;
			}
			// Change from execSync to spawn due to execSync blocking the entire 
			// process causing the SIGTERM/SIGINT event on main.js not fire properly.
			if(option == 'restart application'){
				console.log('User requested an application restart' + '...');
				try{
					let respond = await Utils.httpPost_noBody("http://127.0.0.1:3000/api/v1.0/app/restart");
					if (!respond.ok) {
						console.log('Invalid respond from system container...');
						spawn('systemctl', ['restart', 'docker-compose']);
					} 
				} catch(e){
					console.log('System container is unreachable...');
					spawn('systemctl', ['restart', 'docker-compose']);
				}
			} else {
				console.log('User requested a ' + option + '...');
				spawn(option, [ 'now' ]);
			}
			// execSync('sudo ' + option + ' now');
			res.writeHead(200);
			res.end('');
		});

		//** Validates a network interface. */
		this.dispatcher.onPost('/ifaces_val', (req, res) => {
			const name = req.params.name;
			const ip = req.params.ip;
			const mask = req.params.mask;
			const router = req.params.router;
			const dns = req.params.dns;
			// Check if the interface name was given
			if (!name) {
				res.writeHead(400);
				res.end('The interface name is missing.');
				return;
			}
			// Check if all required values were given
			if (!ip || !mask || !router || !dns) {
				res.writeHead(400);
				res.end('One or more required values are missing.');
				return;
			}
			// Check that the IP and router values are valid
			const VALID_IP4 = /^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
			if (!VALID_IP4.test(ip)) {
				res.writeHead(400);
				res.end('The static IP is missing or invalid.');
				return;
			}
			if (!VALID_IP4.test(router)) {
				res.writeHead(400);
				res.end('The gateway IP is missing or invalid.');
				return;
			}
			// Split and check for missing DNSes
			const dnses = dns.split(' ');
			if (dnses.length == 0 || dnses.every(val => val == '...')) {
				res.writeHead(400);
				res.end('At least one DNS is required.');
				return;
			}
			// Split out the DNSes and check each for validity
			if (dnses.some(val => val != '...' && !VALID_IP4.test(val))) {
				res.writeHead(400);
				res.end('One or more DNS values given is not valid.');
				return;
			}
			res.writeHead(200);
			res.end('');
		});

		/** Updates network interface in the dhcpcd.conf file. */
		this.dispatcher.onPost('/ifaces_re', (req, res) => {
			const name = req.params.name;
			const ip = req.params.ip;
			const mask = req.params.mask;
			const router = req.params.router;
			const dns = req.params.dns.replace('...', '').trim(); // Sanitize empty values from the UI
			// Change the dhcpcd.conf file with the new static IP
			Utils.setStaticIp(name, ip + '/' + mask, router, dns);
			res.writeHead(200);
			res.end('');
		});

		/** Gets the list of network interfaces in the dhcpcd.conf file. */
		this.dispatcher.onGet('/ifaces', (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify(Utils.getStaticIps()));
		});

		/** Deletes a network interface from the dhcpcd.conf file. */
		this.dispatcher.onPost('/ifaces_del', (req, res) => {
			const name = req.params.name;
			Utils.delStaticIp(name);
			res.writeHead(200);
			res.end('');
		});

		// Create a server
		this.server = http.createServer(handleRequest);

		// Lets start our server
		this.server.listen(DEF_PORT, () => {
			// Callback triggered when server is successfully listening. Hurray!
			console.log('HTTP server listening on port ' + DEF_PORT + '.');
		});

		this.initialCacheVal = {
			filePath: 0,
			data: [],
			lineCount: 0,
			startLinePosition: -1,
			linePosition: -1,
			error: ''
		};

		// To cache the data required at the top of table
		this.firstPreFetchData = {
			preAppendData: JSON.parse(JSON.stringify(this.initialCacheVal)),
			preRemoveData: JSON.parse(JSON.stringify(this.initialCacheVal))
		}
		// To cache the data required at the bottom of table
		this.lastPreFetchData = {
			preAppendData: JSON.parse(JSON.stringify(this.initialCacheVal)),
			preRemoveData: JSON.parse(JSON.stringify(this.initialCacheVal))
		}
		// To keep track of log rotation
		this.firstLogTime = '';
		// Returns the log files
		this.dispatcher.onPost('/getLog', async (req, res) => {
			let countPosDir = req.params.countPosDir;
			// Get the refresh event from front end
			let isRefresh = req.params.isRefresh;
			countPosDir = JSON.parse(countPosDir);
			// Convert the filePath input into typeof number
			for (let input of countPosDir) {
				if ('filePath' in input) {
					if (typeof input.filePath === 'string') {
						input.filePath = parseInt(input.filePath);
					}
				}
			}
			// Reset all the variables and cached data if refresh event is detected
			if (isRefresh === 'true') {
				this.resetVal();
			}
			// Check for log rotation before reading the data
			// If log rotated in the middle of the scrolling, force reload the whole page
			if (await this.isLogRotated()) {
				res.writeHead(200);
				res.end('Log is Rotated. Refreshing...');
			}
			res.writeHead(200, { 'Content-Type': 'application/json' });
			res.end(JSON.stringify(await this.setReturnData(countPosDir)));
		});

		// check for compose file update
		this.dispatcher.onGet('/compose', (req, res) => {
			res.writeHead(200, { 'Content-Type': 'application/json' });
			// return system update and state of each flow
			res.end(JSON.stringify({ 'has_updates': this.has_compose_updates }));
		});
	}

	turnOffAllOutputs() {
		this.flows.turnOffAllOutputs();
	}

	setFirstPreAppend(newData) {
		this.firstPreFetchData.preAppendData = JSON.parse(JSON.stringify(newData));
	}

	setFirstPreRemove(newData) {
		this.firstPreFetchData.preRemoveData = JSON.parse(JSON.stringify(newData));
	}

	setLastPreAppend(newData) {
		this.lastPreFetchData.preAppendData = JSON.parse(JSON.stringify(newData));
	}

	setLastPreRemove(newData) {
		this.lastPreFetchData.preRemoveData = JSON.parse(JSON.stringify(newData));
	}

	getFirstPreAppend() {
		return JSON.parse(JSON.stringify(this.firstPreFetchData.preAppendData));
	}

	getFirstPreRemove() {
		return JSON.parse(JSON.stringify(this.firstPreFetchData.preRemoveData));
	}

	getLastPreAppend() {
		return JSON.parse(JSON.stringify(this.lastPreFetchData.preAppendData));
	}

	getLastPreRemove() {
		return JSON.parse(JSON.stringify(this.lastPreFetchData.preRemoveData));
	}

	// Reset all the variables to initial values
	resetVal() {
		this.firstLogTime = '';
		this.setFirstPreAppend(this.initialCacheVal);
		this.setFirstPreRemove(this.initialCacheVal);
		this.setLastPreAppend(this.initialCacheVal);
		this.setLastPreRemove(this.initialCacheVal);
	}

	// To read the file using read_file_lib.js
	// Note: the "filePath" input need to be in typeof number
	async readLine(filePath, countPosDir) {
		if ('filePath' in countPosDir) {
			delete countPosDir.filePath;
		}
		// Get log path according to file number
		filePath = this.getLogPath(filePath);
		const readFile = await readFileFunc(filePath, countPosDir);
		if (readFile.length > 0) {
			for (const data of readFile) {
				if (data.error != '') {
					console.log(`Read log ${filePath} error: ${data.error}`);
				}
			}
		}
		return JSON.parse(JSON.stringify(readFile));
	}

	// To read required number of lines based on input
	// "removeOnly" is used to indicate that the input array "countPosDir" contains only remove-related input
	// By default, the "countPosDir" should either contains both append and remove inputs or contains only append input only
	async readAllLines(countPosDir, removeOnly = false) {
		let hasError = false;
		let allLines = [];
		// To keep track of the line count
		let isAppendFull = false;
		let isRemoveFull = false;
		// The data read to be returned
		let appendData = JSON.parse(JSON.stringify(this.initialCacheVal));
		let removeData = JSON.parse(JSON.stringify(this.initialCacheVal));
		// The local input arguments
		let appendArgs = {};
		let removeArgs = {};
		if (countPosDir.length > 1) {
			appendArgs = JSON.parse(JSON.stringify(countPosDir[0]));
			removeArgs = JSON.parse(JSON.stringify(countPosDir[1]));
		} else if (countPosDir.length > 0) {
			if (removeOnly) {
				removeArgs = JSON.parse(JSON.stringify(countPosDir[0]));
				isAppendFull = true;
			} else {
				appendArgs = JSON.parse(JSON.stringify(countPosDir[0]));
				isRemoveFull = true;
			}
		}
		// Set the initial value of data to avoid returning empty filePath
		if ('filePath' in appendArgs) {
			appendData.filePath = appendArgs.filePath;
		}
		if ('filePath' in removeArgs) {
			removeData.filePath = removeArgs.filePath;
		}
		// Keep looping until the line count is satisfied or no further lines to read
		while (!isAppendFull || !isRemoveFull) {
			let getCurrentLog;
			// Read the file according to the input
			if ('linePosition' in appendArgs && 'linePosition' in removeArgs &&
				'filePath' in appendArgs && 'filePath' in removeArgs) {
				if (appendArgs.filePath != removeArgs.filePath) {
					const temp = await Promise.all([this.readLine(appendArgs.filePath, [appendArgs]), this.readLine(removeArgs.filePath, [removeArgs])]);
					if (temp.length > 0) {
						getCurrentLog = [];
						getCurrentLog.push(JSON.parse(JSON.stringify(temp.shift().shift())));
						getCurrentLog.push(JSON.parse(JSON.stringify(temp.shift().shift())));
					}
				} else {
					getCurrentLog = await this.readLine(appendArgs.filePath, [appendArgs, removeArgs]);
				}
			} else if ('linePosition' in appendArgs && 'filePath' in appendArgs) {
				getCurrentLog = await this.readLine(appendArgs.filePath, [appendArgs]);
			} else if ('linePosition' in removeArgs && 'filePath' in removeArgs) {
				getCurrentLog = await this.readLine(removeArgs.filePath, [removeArgs]);
			}
			// Check for error after fetching the data
			for (let checkError of getCurrentLog) {
				if (checkError.error != '') {
					hasError = true;
					break;
				}
			}
			// Break the "while" loop if error is found
			if (hasError) break;

			// "isHereAdy" is used to make sure the second element of "getCurrentLog" will not enter the same if statement
			let isHereAdy = false;
			for (let i = 0; i < getCurrentLog.length; i++) {
				let isEndOfFile = false;
				let args;
				let localData;
				let appendRemove = '';
				// To set the local variable inside the "for" block
				if ('linePosition' in appendArgs && !isHereAdy) {
					isHereAdy = true;
					args = JSON.parse(JSON.stringify(appendArgs));
					localData = JSON.parse(JSON.stringify(appendData));
					appendRemove = 'append';
				} else if ('linePosition' in removeArgs) {
					args = JSON.parse(JSON.stringify(removeArgs));
					localData = JSON.parse(JSON.stringify(removeData));
					appendRemove = 'remove';
				}
				// If the line count read from file matches the input arguments line count, set to full
				if (getCurrentLog[i].lineCount == args.lineCount) {
					appendRemove == 'append' ? isAppendFull = true : isRemoveFull = true;
					if (getCurrentLog[i].linePosition == -1 || getCurrentLog[i].linePosition == 0) {
						isEndOfFile = true;
					}
				} else {
					isEndOfFile = true;
					// If the line count read doesn't fulfill the required line count, update the line count for subsequent read
					args.lineCount -= getCurrentLog[i].lineCount;
					// update the input line position to -1 for subsequent read
					// "-1" will be interpreted as "start reading from start/end of file" in the read_file_lib.js
					args.linePosition = -1;
				}
				if (isEndOfFile) {
					// Check for subsequent valid log path
					const nextFileCheck = await this.checkLogRotatePath(args.direction, appendRemove, args.filePath);
					// If there is no changes to the current log path (no further lines to read), set to fulfill
					if (nextFileCheck == -1) {
						appendRemove == 'append' ? isAppendFull = true : isRemoveFull = true;
						// Set the line position to be returned to frontend to -99 and 0 accordingly 
						// to indicate that this is the end of all log files
						args.direction == 'forward' ? getCurrentLog[i].linePosition = -99 : getCurrentLog[i].linePosition = 0;
					} else {
						// Set the line position to -1 to the frontend
						// to indicate that this is the end of current file only, but still have subsequent log file
						getCurrentLog[i].linePosition = -1;
						if (!isAppendFull || !isRemoveFull) {
							args.filePath = nextFileCheck;
						}
					}
				}
				// Update and concatenate the data
				localData.data = localData.data.concat(getCurrentLog[i].data);
				localData.lineCount += getCurrentLog[i].lineCount;
				localData.linePosition = getCurrentLog[i].linePosition;
				localData.error = getCurrentLog[i].error;
				localData.filePath = args.filePath;
				// Set the local variable to the inputs for subsequent read and the data to be returned 
				if (appendRemove == 'append') {
					isAppendFull ? appendArgs = {} : appendArgs = JSON.parse(JSON.stringify(args));
					appendData = JSON.parse(JSON.stringify(localData));
				} else {
					isRemoveFull ? removeArgs = {} : removeArgs = JSON.parse(JSON.stringify(args));
					removeData = JSON.parse(JSON.stringify(localData));
				}
			}
		}
		if (countPosDir.length > 1) {
			allLines.push(appendData);
			allLines.push(removeData);
		} else if (countPosDir.length > 0) {
			removeOnly ? allLines.push(removeData) : allLines.push(appendData);
		}
		return JSON.parse(JSON.stringify(allLines));
	}

	// To prefetch and cache the data for next read file
	async preFetch(countPosDir) {
		const preFetch = await this.readAllLines(countPosDir);
		for (let i = 0; i < preFetch.length; i++) {
			let selectedData = countPosDir[i].direction == 'backward' ? this.getLastPreAppend() : this.getFirstPreAppend();
			if (i == 1) {
				selectedData = countPosDir[i].direction == 'backward' ? this.getFirstPreRemove() : this.getLastPreRemove();
			}
			if (preFetch[i].error != '') {
				selectedData.error = preFetch[i].error;
			} else {
				selectedData.filePath = preFetch[i].filePath;
				selectedData.data = JSON.parse(JSON.stringify(preFetch[i].data));
				selectedData.lineCount = preFetch[i].lineCount;
				selectedData.startLinePosition = countPosDir[i].linePosition;
				selectedData.linePosition = preFetch[i].linePosition;
			}
			i == 0 ?
				(countPosDir[i].direction == 'backward' ? this.setLastPreAppend(selectedData) : this.setFirstPreAppend(selectedData)) :
				(countPosDir[i].direction == 'backward' ? this.setFirstPreRemove(selectedData) : this.setLastPreRemove(selectedData));
		}
	}

	// To set the return value to log.html and handle the input arguments for next caching
	async setReturnData(countPosDir) {
		let readFile = [];
		let isAppendCached = true;
		let isRemoveCached = true;
		let appendArgs = JSON.parse(JSON.stringify(countPosDir[0]));
		let removeArgs;
		const tempInput = JSON.parse(JSON.stringify(countPosDir));
		// Get the cached data
		for (let i = 0; i < tempInput.length; i++) {
			let isCached = true;
			let selectedData = tempInput[i].direction == 'backward' ? this.getLastPreAppend() : this.getFirstPreAppend();
			if (i == 1) {
				removeArgs = JSON.parse(JSON.stringify(tempInput[i]));
				selectedData = tempInput[i].direction == 'backward' ? this.getFirstPreRemove() : this.getLastPreRemove();
			}
			if (selectedData.data.length == 0 && selectedData.error == '') {
				isCached = false;
			} else {
				// Check for the cached data start position to verify whether the cached data is same as requested data
				if (selectedData.startLinePosition == tempInput[i].linePosition) {
					if (i == 0) {
						readFile.unshift(selectedData);
						countPosDir.shift();
					} else if (i == 1) {
						readFile.push(selectedData);
						countPosDir.pop();
					}
				} else {
					isCached = false;
				}
			}
			i == 0 ? isAppendCached = isCached : isRemoveCached = isCached;
		}
		// If no/wrong cached data, fetch the data
		let getCurrentLog;
		if (!isAppendCached || !isRemoveCached) {
			if (!isAppendCached && !isRemoveCached) {
				getCurrentLog = await this.readAllLines(countPosDir);
				readFile.push(JSON.parse(JSON.stringify(getCurrentLog.shift())));
				readFile.push(JSON.parse(JSON.stringify(getCurrentLog.shift())));
			} else if (!isAppendCached) {
				getCurrentLog = await this.readAllLines(countPosDir);
				readFile.unshift(JSON.parse(JSON.stringify(getCurrentLog.shift())));
			} else if (!isRemoveCached) {
				getCurrentLog = await this.readAllLines(countPosDir, true);
				readFile.push(JSON.parse(JSON.stringify(getCurrentLog.shift())));
			}
		}
		// Cache the next required data
		if (readFile.length > 1) {
			if (readFile[1].error == '' && readFile[0].error == ''
				&& 'linePosition' in removeArgs && 'linePosition' in appendArgs
				&& readFile[1].filePath >= 0 && readFile[0].filePath >= 0) {
				removeArgs.linePosition = readFile[1].linePosition;
				removeArgs.filePath = readFile[1].filePath;
				appendArgs.linePosition = readFile[0].linePosition;
				appendArgs.filePath = readFile[0].filePath;
				// Cache data without awaiting
				this.preFetch([appendArgs, removeArgs]);
			}
		} else if (readFile.length > 0) {
			if (readFile[0].error == '' && 'linePosition' in appendArgs && readFile[0].filePath >= 0) {
				appendArgs.linePosition = readFile[0].linePosition;
				appendArgs.filePath = readFile[0].filePath;
				this.preFetch([appendArgs]);
			}
		}
		return JSON.parse(JSON.stringify(readFile));
	}

	// To check the log rotation file and return the log path if subsequent valid log path is found
	async checkLogRotatePath(readDirection, appendRemove, currLogPath) {
		let nextLogPath;
		if (appendRemove == 'append') {
			nextLogPath = readDirection == 'backward' ? currLogPath + 1 : (currLogPath - 1 >= 0 ? currLogPath - 1 : 0);
		} else if (appendRemove == 'remove') {
			nextLogPath = readDirection == 'backward' ? currLogPath + 1 : (currLogPath - 1 >= 0 ? currLogPath - 1 : 0);
		}
		const currLogReadArgs = { lineCount: 1, linePosition: -1, direction: 'backward' };
		const nextLogReadArgs = { lineCount: 1, linePosition: -1, direction: 'forward' };
		const [verifyNextTime, verifyCurrTime] = await Promise.all([this.readLine(nextLogPath, [nextLogReadArgs]), this.readLine(currLogPath, [currLogReadArgs])]);
		// To verify the timestamp of the new log file for log rotation
		if (verifyNextTime.length > 0 && verifyCurrTime.length > 0) {
			if (verifyNextTime[0].error == '' && verifyCurrTime[0].error == '') {
				const nextLogTime = JSON.parse(verifyNextTime[0].data[0]);
				const currLogTime = JSON.parse(verifyCurrTime[0].data[0]);
				if (readDirection == 'backward') {
					if (new Date(currLogTime.time) >= new Date(nextLogTime.time)) {
						if (currLogPath != nextLogPath) {
							return nextLogPath;
						}
					}
				} else {
					if (new Date(currLogTime.time) <= new Date(nextLogTime.time)) {
						if (currLogPath != nextLogPath) {
							return nextLogPath;
						}
					}
				}
			}
		}
		return -1;
	}

	// To check whether the log is rotated
	async isLogRotated() {
		const checkCurrMaxArgs = { lineCount: 1, linePosition: -1, direction: 'forward' };
		const logRotate = await this.readLine(0, [checkCurrMaxArgs]);
		if (logRotate.length > 0) {
			if (logRotate[0].error == '' && logRotate[0].data.length > 0) {
				const tempLog = JSON.parse(logRotate[0].data[0]);
				if (new Date(tempLog.time) > new Date(this.firstLogTime)) {
					return true;
				}
				this.firstLogTime = tempLog.time;
			}
		}
		return false;
	}

	// To return LOG_PATH according to the file number
	getLogPath(logFileNum) {
		return (logFileNum == 0 ? LOG_PATH : LOG_PATH + '.' + logFileNum);
	}
}

module.exports = HttpStatusInterface;