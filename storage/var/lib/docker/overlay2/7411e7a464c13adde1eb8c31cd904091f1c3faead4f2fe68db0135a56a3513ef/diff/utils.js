"use strict";

// ╓─────────────────────────────────────────╖
// ║ Copyright 2019-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Incubation Team

const fs = require('fs');
const http = require('http');
const HID = require('node-hid');
const https = require('https');
const execSync = require('child_process').execSync;
const FormData = require('form-data')
const DHCPCD_CONF = './etc/dhcpcd.conf';

/** Enums for the parts of an interface in dhcpdd.conf file. */
const _IF_ = {
    _OUTSIDE_: 0,
    _START_: 10,
    _IP_: 100,
    _ROUTER_: 200,
    _DNS_: 300,
    _INSIDE_: 400,
    _END_: 1000
}

const _IF_PART_ = {
    _INTERFACE_: 'interface ',
    _IP_: 'static ip_address=',
    _ROUTER_: 'static routers=',
    _DNS_: 'static domain_name_servers='
}

class Utils {

    static getCurrentIp() {
        return new Promise((resolve, reject) => {
            const ip_req = http.get('http://whatismyip.docker.corp.jabil.org/', resp => {
                let data = '';
                resp.on('data', chunk => data += chunk);
                resp.on('end', () => resolve(data));
            });
            ip_req.on('error', e => {
                if ('code' in e && e.code === 'EAI_AGAIN' && e.syscall === 'getaddrinfo') {
                    console.log('Could not reach http://whatismyip.docker.corp.jabil.org/.');
                } else { console.error(e); }
                resolve(null);
            });
            ip_req.end();
        });
    }

    /** Returns the status of the service that monitors dhcpcd.conf for changes. **/
    static getDhcpMonitorStatus() {
        try {
            const raw = execSync('sudo systemctl status restart-dhcpcd.path');
            return {
                enabled: true,
                started: raw.includes('Active: active')
            };
        } catch (e) {
            // If the error was not because the service
            // was not registered yet then rethrow
            if (!e.message.includes('Command failed')) {
                throw e;
            }
        }
        // If code reaches here then it means the service has not been registered yet
        return {
            enabled: false,
            started: false
        }
    }

    static parseDhcpCd(parseCallback) {
        const handle_ = (iface, part, key, value) => {
            if (!key) { key = '' }
            parseCallback(iface, part, key, value);
        };
        let iface = null;
        // Read the config file line by line
        fs.readFileSync(DHCPCD_CONF, 'utf8').split(/\r?\n/).forEach(line => {
            // Search for the interface line
            if (iface) {
                // Search for the static IP address and change if
                // Do the same for routers and DNSes
                if (line.startsWith(_IF_PART_._IP_)) {
                    handle_(iface, _IF_._IP_, _IF_PART_._IP_, line.substring(_IF_PART_._IP_.length));
                } else if (line.startsWith(_IF_PART_._ROUTER_)) {
                    handle_(iface, _IF_._ROUTER_, _IF_PART_._ROUTER_, line.substring(_IF_PART_._ROUTER_.length));
                } else if (line.startsWith(_IF_PART_._DNS_)) {
                    handle_(iface, _IF_._DNS_, _IF_PART_._DNS_, line.substring(_IF_PART_._DNS_.length));
                } else if (line.startsWith(_IF_PART_._INTERFACE_)) {
                    // We have found the start of another interface
                    // then we assume the end of the current interface
                    handle_(iface, _IF_._END_, null, '');
                    // Capture the new interface
                    iface = line.substring(_IF_PART_._INTERFACE_.length)
                    handle_(iface, _IF_._START_, null, line);
                } else {
                    // For all other lines in this interface we call
                    // the callback verbatim
                    handle_(iface, _IF_._INSIDE_, null, line);
                };
                // Check for the start of the interface section
            } else if (line.startsWith(_IF_PART_._INTERFACE_)) {
                iface = line.substring(_IF_PART_._INTERFACE_.length);
                handle_(iface, _IF_._START_, null, line);
            } else {
                // Call the callback verbatim
                handle_(null, _IF_._OUTSIDE_, null, line);
            }
        });
    }

    static setStaticIp(iface, ipAndMask, router, dns) {
        let found = false;
        let ip_set = false;
        let router_set = false;
        let dns_set = false;
        let output = '';
        // Helper method for appending text to the end of output with line feed
        const _append_ = (key, value) => {
            if (key) { output += key; }
            output += value + '\n';
        }
        // Read the config file line by line
        Utils.parseDhcpCd(
            (i, part, key, value) => {
                if (iface == i) {
                    found = true;
                    switch (part) {
                        case _IF_._IP_: _append_(key, ipAndMask); ip_set = true; break;
                        case _IF_._ROUTER_: _append_(key, router); router_set = true; break;
                        case _IF_._DNS_: _append_(key, dns); dns_set = true; break;
                        case _IF_._END_:
                            // Check if all the required values have been set
                            // If not set them here
                            if (!ip_set) { _append_(_IF_PART_._IP_, ipAndMask); }
                            if (!router_set) { _append_(_IF_PART_._ROUTER_, router); }
                            if (!dns_set) { _append_(_IF_PART_._DNS_, dns); }
                            break;
                        default:
                            _append_(key, value);
                            break;
                    }
                } else {
                    _append_(key, value);
                }
            });
        // If the interface section was not found then append it
        if (!found) {
            console.log('No interface \'' + iface + '\' definition found in dhcpcd.conf file. Appending.');
            _append_(_IF_PART_._INTERFACE_, iface);
            _append_(_IF_PART_._IP_, ipAndMask);
            _append_(_IF_PART_._ROUTER_, router);
            _append_(_IF_PART_._DNS_, dns);
        }
        // Write the text back to the file
        console.log('Interface \'' + iface + '\' set to static IP of ' + ipAndMask + '.');
        fs.writeFileSync(DHCPCD_CONF, output);
    }

    static getStaticIps() {
        const ifaces = [];
        let iface = null;
        Utils.parseDhcpCd((i, part, key, value) => {
            switch (part) {
                case _IF_._START_:
                    iface = {
                        name: i,
                        ip: '',
                        mask: '24',
                        router: '',
                        dns: ''
                    };
                    ifaces.push(iface);
                    break;
                case _IF_._IP_:
                    let val = value.split('/');
                    iface.ip = val[0];
                    iface.mask = val[1];
                    break;
                case _IF_._ROUTER_:
                    iface.router = value;
                    break;
                case _IF_._DNS_:
                    iface.dns = value;
                    break;
            }
        });
        return ifaces;
    }

    static delStaticIp(iface) {
        let output = '';
        // Helper method for appending text to the end of output with line feed
        const _append_ = (key, value) => {
            if (key) { output += key; }
            output += value + '\n';
        }
        // Read the config file line by line. Anything not from the given interface we append
        // Everything from the given interface we discard
        Utils.parseDhcpCd(
            (i, part, key, value) => {
                if (iface !== i) {
                    _append_(key, value);
                }
            });
        // Write the text back to the file
        console.log('Interface \'' + iface + '\' deleted from dhcpcd.conf file.');
        fs.writeFileSync(DHCPCD_CONF, output);
    }

    static getKernelVersion() {
        try {
            return execSync('uname -r').toString().split('-')[0];
        }
        catch (e) {
            console.log('There was an error trying to get the OS kernel version.');
            console.error(e);
            return '';
        }
    }

    static compareVersion(v1, v2) {
        if (v1 && v1.match(/(\d+\.\d+.\d+)/)) {
            v1 = v1.split('.');
            v2 = v2.split('.');
            const k = Math.min(v1.length, v2.length);
            for (let i = 0; i < k; ++i) {
                v1[i] = parseInt(v1[i], 10);
                v2[i] = parseInt(v2[i], 10);
                if (v1[i] > v2[i]) { return 1; }
                if (v1[i] < v2[i]) { return -1; }
            }
            return v1.length == v2.length ? 0 : (v1.length < v2.length ? -1 : 1);
        } else {
            // If no version number returned (e.g. when permission denied)
            // we set the pins using the old settings, i.e. return 1
            return 1
        }
    }

    static httpGet(url) {
        // select http or https module, depending on reqested url
        const lib = url.startsWith('https') ? https : http;
        return new Promise((resolve, reject) => {
            lib.get(url, response => {
                let body = '';
                response.on('data', chunk => body += chunk);
                response.on('end', () => resolve({
                    "ok": response.statusCode >= 200 && response.statusCode < 300,
                    "response": response,
                    "data": body
                }));
            }).on('error', e => reject({
                "ok": false,
                "error": e
            })).end();
        });
    }

    static httpPost(url, contenttype, data) {
        // select http or https module, depending on reqested url
        const lib = url.startsWith('https') ? https : http;
        const opts = {
            method: 'POST',
            agent: false,
            headers: {
                'Content-Type': contenttype,
                'Content-Length': data ? Buffer.byteLength(data) : 0
            }
        }
        return new Promise((resolve, reject) => {
            lib.request(url, opts, response => {
                let body = '';
                response.on('data', chunk => body += chunk);
                response.on('end', () => resolve({
                    "ok": response.statusCode >= 200 && response.statusCode < 300,
                    "response": response,
                    "data": body
                }));
            }).on('error', e => reject({
                "ok": false,
                "error": e
            })).end(data);
        });
    }

    //http post request without body
    static httpPost_noBody(url) {
        // select http or https module, depending on reqested url
        const lib = url.startsWith('https') ? https : http;
        const opts = {
            method: 'POST'
        }
        return new Promise((resolve, reject) => {
            lib.request(url, opts, response => {
                let body = '';
                response.on('data', chunk => body += chunk);
                response.on('end', () => resolve({
                    "ok": response.statusCode >= 200 && response.statusCode < 300,
                    "response": response,
                    "data": body
                }));
            }).on('error', e => reject({
                "ok": false,
                "error": e
            })).end();
        });
    }

    static httpUpload(url, filepath) {
        const readStream = fs.createReadStream(filepath);
        const form = new FormData();
        form.append('document', readStream);
        const headers = Object.assign({
            'Accept': 'application/json',
            'Authorization': 'bearer <tokenid>'
        }, form.getHeaders());

        // select http or https module, depending on reqested url
        const lib = url.startsWith('https') ? https : http;
        const opts = {
            method: 'POST',
            headers: headers
        }
        return new Promise((resolve, reject) => {
            const req = lib.request(url, opts, response => {
                response.on('data', chunk => console.log(chunk.toString()));
                response.on('end', () => {
                    resolve({
                        "ok": response.statusCode >= 200 && response.statusCode < 300,
                        "response": response
                    })
                }
                );
            }).on('error', e => reject({
                "ok": false,
                "error": e
            }))
            form.pipe(req)
        });
    }

    static getUsbPaths() {
        var devices = HID.devices();
        const ports = []
        devices.forEach(device => {
            // Filter out other HID devices except scanners.
            if (device.path && device.serialNumber) {
                ports.push(device.path);
            }
        });
        return ports;
    }

}

module.exports = Utils;