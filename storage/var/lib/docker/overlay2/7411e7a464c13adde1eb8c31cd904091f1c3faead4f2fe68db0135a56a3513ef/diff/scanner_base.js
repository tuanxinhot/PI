const EventEmitter = require('events');
const DISCARD_THERSHOLD = 100 //ms

class ScannerBase extends EventEmitter {
    #lastreadlinetime;
    #lastValue;
    #repeatCount;

    // @param   path: path of the device connected to (/dev/ttySC0 etc).
    // @param   strRemove: data received that is to be trimmed off (spacing etc).
    //                      it is neccessary because data received on USB & serial is different in format.
    constructor(path, strRemove) {
        super();
        this.path = path;
        this.strRemove = strRemove;
        this.#lastreadlinetime = new Date(-8640000000000000); // Set to earliest time possible
        this.#lastValue = null;
        this.#repeatCount = 0;
    }

    read(value) {
        value = value.trim().replace(this.strRemove, '');

        const prevreadtime = this.#lastreadlinetime
        this.#lastreadlinetime = Date.now();

        if (this.#lastValue === value) {
            this.#repeatCount++;
            this.emit_scanned(value);
            return;
        }

        /* We only need the first line when multiple lines are captured in a single scan.
        Therefore, we check for the time taken for each line, we only emit the value if
        the difference in time for the previous line and current line exceeds 0.1 seconds. */
        if (Date.now() - prevreadtime < DISCARD_THERSHOLD) {
            if (this.#repeatCount === 0) {
                console.log(`   IGNORED: Scanner data on ${this.path}: ${value}`);
            }
            return;
        }

        // If there were repeats of the previous value then log them
        if (this.#repeatCount > 0) {
            console.log(`Scanner data on ${this.path}: ${this.#lastValue} [${this.#repeatCount}x]`);
        }

        this.#lastValue = value;
        this.#repeatCount = 0;
        console.log(`Scanner data on ${this.path}: ${value}`);
        this.emit_scanned(value);
    }

    pulseOn() {
        // Implement in sub classes
    }

    pulseOff() {
        // Implement in sub classes
    }

    dispose() {
        // Implement in sub classes
    }

    // Change this to private method, it only called by read method,
    // modify the other scanners code to call read method,
    // they will not call emit_scanned method anymore.
    emit_scanned(value) {
        this.emit('scanned', value);
    }

}

module.exports = ScannerBase;