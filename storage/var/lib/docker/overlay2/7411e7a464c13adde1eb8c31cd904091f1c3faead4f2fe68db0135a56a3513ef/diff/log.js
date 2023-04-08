'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2019-2020 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Product Team

const fs = require('fs'),readline = require('readline');
const stream = require('stream');
const http = require('http');
const https = require('https');
const Utils = require('./utils.js');
const SysConfig = require('./config.system.js');

class Log {

    constructor() {
        let settings = SysConfig.getSettings(updateSettings => settings = updateSettings);
        const container_id = fs.readFileSync('/proc/self/cgroup','utf8').split('\n')[0].split('/')[2]
        const LOG_DIR = '/log/' + container_id + '/';
        const LOG_FILE = container_id + '-json.log';
        const LOG_PATH = LOG_DIR + LOG_FILE;
        const SN = fs.readFileSync('/proc/cpuinfo', 'utf8').split('\n').find(line => line.startsWith('Serial')).split(':')[1].trim();
        const SN_JSON = JSON.stringify({ serial_number: SN });
        const INIT_DATE = new Date(2000, 0, 1);
        // starting byte for log file.
        const START_BYTE = 0

        this.mac_address = 'TBR'
        this.ip_address =  '';
        this.timestamp = INIT_DATE;

        if (fs.existsSync('/log/eth0/address') && fs.existsSync('/log/wlan0/address')) {
            this.mac_address = fs.readFileSync('/log/eth0/address', 'utf8').replace('\n', '') + ' ' + fs.readFileSync('/log/wlan0/address', 'utf8').replace('\n', '')
        } else {
            console.log("LOG: MAC address paths not mounted.");
        }

        // Read a stream and send its contents to Pico HQ
        // exp of new_lines format
        /*
        {"ip_address": "0.0.0.0",
        "serial_number": "00000000c27a363f",
        "mac_address": "b8:27:eb:7a:36:3f b8:27:eb:2f:63:6a",
        "logs":[
            {   "log": "X",
                "stream": "stdout",
                "time": "2020-02-25T11:21:22.324398z",
            }]
        }
        */      
        const read_and_post = async strm => {
            const new_lines = JSON.stringify({
                "logs"          : JSON.parse("["+strm.read().toString().replace(/,*$/, '')+"]"), 
                "serial_number" : SN,
                "ip_address"    : this.ip_address, 
                "mac_address"   : this.mac_address
            });
            let error_count = 0;
            do {
                const res = await Utils.httpPost(`https://${settings.hq.endpoint}${settings.logs.log_api}`, 'application/json', new_lines);
                if (res.ok) {
                    console.log('LOG: Logs sent. ' + res.data);
                    return true;
                } 
                if (res.error) {
                    console.log('LOG: Error sending logs.');
                    console.error(res.error);
                } else {
                    console.log(`LOG: Sending logs met ${res.response.statusCode} ${res.response.statusMessage}.`);
                }
                // Retry 3 times, if still fails then exit
                error_count++;
            } while (error_count < 3);
            return false;
        }

        const send_logs = async () => {
            // Get the public IP for this Pico
            if (!this.ip_address) {
                const curr_ip = await Utils.getCurrentIp();
                if (!curr_ip) {
                    console.log('LOG: Could not get the IP for this Pico. Will try again later.');
                    return;
                }
                this.ip_address = curr_ip;
            }
            // Get the timestamp of the last log entry we sent to Pico HQ
            if (this.timestamp == INIT_DATE) {
                const ts_res = await Utils.httpPost(`https://${settings.hq.endpoint}${settings.logs.ts_api}`, 'application/json', SN_JSON);
                if (ts_res.ok) {
                    this.timestamp = new Date(ts_res.data);
                } else {
                    if (ts_res.error) {
                        if (ts_res.error.errno == 'ETIMEDOUT') {
                            console.log('LOG: Connection timed out, unable to reach Pico HQ.');
                        } else {
                            console.log('LOG: Error trying to establish connection Pico HQ.');
                            console.error(ts_res.error)
                        }
                    } else {
                        console.log(`LOG: Getting timestamp met ${ts_res.response.statusCode} ${ts_res.response.statusMessage}.`);
                    }
                    return;
                }
            }

            // Check if log file exists
            if(!fs.existsSync(LOG_PATH)) {
                console.log('LOG: No log file exists to send to Pico HQ.');
                return;
            }
            const fileLength = fs.statSync(LOG_PATH)['size'];
            const instream = fs.createReadStream(LOG_PATH, {
                encoding: 'utf8', 
                start: START_BYTE, 
                end: fileLength-1
            });
            const outstream = new stream.Readable({ read() { } });
            const rl = readline.createInterface({
                input: instream,
                terminal: false
            });
            console.log('LOG: Starting log processing...')
            for await (let line of rl) {
                // .replace(/\u0000/g, "") fixed JSON.parse syntax error(Unexpected token '\u0000')
                line = JSON.parse(line.replace(/\u0000/g, ''))
                // only send the line if the timestamp is after what we had previously sent
                const line_ts = new Date(line.time.replace('T', ' '));
                if (line_ts >= this.timestamp) {
                    this.timestamp = line_ts;
                    line = JSON.stringify(line);
                    outstream.push(line + ',');
                    // Send when the byte length threshold is met
                    if (outstream.readableLength > settings.logs.bytes_per_send) {
                        let sent_ok = await read_and_post(outstream);
                        if (!sent_ok) { break; }
                    }
                }
            }
            //send left over log msg in stream
            if (outstream.readableLength > 0 ) {
                await read_and_post(outstream);
            }
        }

        // Start the timer to send the logs
        setInterval(send_logs, settings.logs.send_frequency_mins * 60 * 1000);

    }
}
module.exports = Log;
