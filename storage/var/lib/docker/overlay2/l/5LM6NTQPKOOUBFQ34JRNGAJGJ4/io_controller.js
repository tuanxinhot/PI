'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2016-2021 - Jabil Circuit Inc ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Product Team

const gpio = require('onoff').Gpio;
const MachineState = require('./machine_state.js');
const _E_ = MachineState._EVENTS_;

/*
INPUTS
511 -- IO1
510 -- OI2
509 -- IO3
508 -- OI4

OUTPUTS (?)
504 -- IO1 
505 -- OI2
506 -- IO3
507 -- OI4

504-507 are the outputs 
508-511 are the inputs 
*/


const _toggle_ = (pin, v) => {
    if (pin) { pin.write(v, e => { if (e) { console.error(e); }})}
}

const _on_ = pin => _toggle_(pin, gpio.HIGH);

const _off_ = pin => _toggle_(pin, gpio.LOW);

class InputOutput {

    constructor(stateMachine) {
        // Gets on signal when the sensor on the conveyor (upstream) senses a board
        this.inputUpstreamBoardAvailable = null;
        // Gives on signal to the downstream machine to tell it there is a board ready to be transferred
        this.outputReadyToTransfer = null;
        // Gets on signal when the downstream machine is ready to receive a board 
        this.inputDownstreamReady = null; 
        // Gives on signal to tell the conveyor (upstream) to transfer a board
        this.outputUpstreamTransfer = null; 

        stateMachine.on(_E_._BYPASS_BOARD_OK_, (state, serial) => {
            console.log('■■■ ba out -> 1 ■■■');
            _on_(this.outputReadyToTransfer);
        });

        stateMachine.on(_E_._BOARD_OK_, (state, serial) => {
            // If the board is transferring then we don't change any IO state until
            // the board has finished transferring whcih will be handled by the 'transferred' event handler
            if (state.Transfer) {
                return;
            }
            // By SMEMA standards, when a board is available and good then we short pins 3 and 4
            // of the downstream machine
            console.log('■■■ ba out -> 1 ■■■')
            _on_(this.outputReadyToTransfer);
        });

        stateMachine.on((_E_._BOARD_OUST_ || _E_._BOARD_OFF_), (state, serial) => {
            // Board has left conveyor or was manually removed, therefore stop the conveyor
            console.log('■■■ ba out -> 0 ■■■');
            _off_(this.outputReadyToTransfer);            
        });

        stateMachine.on(_E_._TRANSFERRING_, (state, serial) => {
            // Signal the conveyor to transfer the board
            console.log('■■■ mr out -> 1 ■■■');
            _on_(this.outputUpstreamTransfer);
        });

        stateMachine.on(_E_._STOPTRANSFER_, (state, serial) => {
            // Signal the conveyor to stop transfer the board
            console.log('■■■ mr out -> 0 ■■■');
            _off_(this.outputUpstreamTransfer);
        });

        stateMachine.on(_E_._TRANSFERRED_, (state, serial) => {
            // Turn off the IO ports
            console.log('■■■ mr out, ba out -> 0 ■■■');
            _off_(this.outputReadyToTransfer);
            _off_(this.outputUpstreamTransfer);
        });

        // process.on('SIGINT', () => { this.dispose(); });
        // process.on('SIGTERM', () => { this.dispose(); });
        // process.on('SIGQUIT', () => { this.dispose(); });
        // process.on('SIGABRT', () => { this.dispose(); });
    }

    init(ba_in, ba_out, mr_in, mr_out) {
        // Gets on signal when the sensor on the conveyor (upstream) senses a board
        this.inputUpstreamBoardAvailable = new gpio(ba_in, 'in');
        // Gives on signal to query if the downstream machine is ready to receive a board
        this.outputReadyToTransfer = new gpio(ba_out, 'out');
        // Gets on signal when the downstream machine is ready to receive a board 
        this.inputDownstreamReady = new gpio(mr_in, 'in'); 
        // Gives on signal to tell the conveyor (upstream) to transfer a board
        this.outputUpstreamTransfer = new gpio(mr_out, 'out'); 

        // Initialise GPIO pins
        _off_(this.outputUpstreamTransfer);
        _off_(this.outputReadyToTransfer);
    }

    getUpstreamBoardAvailable() {
        if (!this.inputUpstreamBoardAvailable) {
            return false;
        }
        return Boolean(this.inputUpstreamBoardAvailable.readSync());
    }

    getDownstreamReady() {
        if (!this.inputDownstreamReady) {
            return false;
        }
        return Boolean(this.inputDownstreamReady.readSync());
    }

    turnOffBaMrOut() {
        _off_(this.outputReadyToTransfer);
        _off_(this.outputUpstreamTransfer);
    }

    dispose() {
        this.inputUpstreamBoardAvailable.unexport();
        this.outputReadyToTransfer.unexport();
        this.inputDownstreamReady.unexport();
        this.outputUpstreamTransfer.unexport();

        // if (this.inputUpstreamBoardAvailable) { this.inputUpstreamBoardAvailable.unexport(); }
        // if (this.outputReadyToTransfer) { this.outputReadyToTransfer.unexport(); }
        // if (this.inputDownstreamReady) { this.inputDownstreamReady.unexport(); }
        // if (this.outputUpstreamTransfer) { this.outputUpstreamTransfer.unexport(); }
		// process.off('SIGINT', () => { this.dispose(); });
		// process.off('SIGTERM', () => { this.dispose(); });
		// process.off('SIGQUIT', () => { this.dispose(); });
		// process.off('SIGABRT', () => { this.dispose(); });
    }

}

module.exports = InputOutput;