const gpio = require('onoff').Gpio;
const SerialPort = require('serialport');
const ScannerBase = require('./scanner_base.js');
const Regex = SerialPort.parsers.Regex;

const _toggle_ = (pin, v) => {
    if (pin) { pin.write(v, e => { if (e) { console.error(e); }})}
}

class SerialScanner extends ScannerBase {

    constructor(path, baud, triggerPin) {
        super(path, /(^\uFFFD+|^\u0000+)/g);
        this.inputDevice = new SerialPort(path, { 'baudRate': baud });
        this.parser = new Regex({ regex: /[\r\n|\n|\r]+/ });
        this.inputDevice.pipe(this.parser)
        this.parser.on('data', data => this.read(data));
        this.pin = new gpio(triggerPin, 'out');
        _toggle_(this.pin, gpio.LOW);
    }

    pulseOn() {
        _toggle_(this.pin, gpio.HIGH);
    }

    pulseOff() {
        _toggle_(this.pin, gpio.LOW);
    }

    dispose() {
        if (!this.inputDevice.isOpen) {
            console.log('Serial scanner port is already closed.');
        } else {
            console.log('Closing scanner serial port...');
            this.inputDevice.close(err => {
                if (err) {
                    console.log('Serial port closed with error.');
                    console.error(err);
                    return;
                }
                console.log('Scanner serial port closed.');
            });
        }
        if (this.pin) {
            this.pin.unexport();
            console.log('Closed scanner trigger pin.');
        }
        
    }

}

module.exports = SerialScanner;
