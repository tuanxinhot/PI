'use strict';

// ╓─────────────────────────────────────────╖
// ║ Copyright 2021 - Jabil Circuit Inc      ║
// ╙─────────────────────────────────────────╜
// Awesomeness courtesy of the Product Team

const { performance }= require('perf_hooks');
const test = require('ava');
const testee = require('./machine_state.js');
const State = testee.State;
const _MODE_ = testee._MODE_;
const _EVENTS_ = testee._EVENTS_;
const _VAL_TRIGGER_ = testee._VAL_TRIGGER_;

// ╓────────────────────────────────────────────────────────────────────────────────────────╖
// ║ Goals of these unit tests are to check that:											║
// ║ 1) initial state is correct      														║
// ║ 2) serial number is set correctly      												║
// ║ 3) the diff properties change correctly when set and appropriate events are raised     ║
// ╙────────────────────────────────────────────────────────────────────────────────────────╜

// Helper method to block the current thread for a period of time
const snooze = ms => new Promise(resolve => setTimeout(resolve, ms));

// Helper method to create a new state with UpstreamBoardAvailable turned on
const new_with_ba = () => {
	const state = new State();
	state.changeState('UpstreamBoardAvailable', true);
	return state;
}

// ╓────────────────────────────────────────╖
// ║ Constructor							║
// ╙────────────────────────────────────────╜

// Helper method to create a new state and check a property is falsy
const check_init_state = (t, propGetter) => {
	const state = new State();
	const vals = state.getState();
	t.false(propGetter(vals));
}

test('Constructor: DownstreamReady = false', check_init_state, state => state.DownstreamReady);

test('Constructor: UpstreamBoardAvailable = false', check_init_state, state => state.UpstreamBoardAvailable);

test('Constructor: UpstreamBoardOK = false', check_init_state, state => state.UpstreamBoardOK);

test('Constructor: Transfer = false', check_init_state, state => state.Transfer);


// ╓────────────────────────────────────────╖
// ║ setSerialTop + setSerialBottom			║
// ╙────────────────────────────────────────╜

const top_target = { set: (state, serial) => state.setSerialTop(serial), get: state => state.getSerials().Top };
const bottom_target =  { set: (state, serial) => state.setSerialBottom(serial), get: state => state.getSerials().Bottom };

const test_serial = (target, t, ba, perform) => {
	const state = new State();
	if (ba) {
		state.changeState('UpstreamBoardAvailable', true);
	}
	perform(t, target, state);
};

const BA_OFF = false, BA_ON = true;

const test_top = (t, ba, perform) => test_serial(top_target, t, ba, perform);
test_top.title = (text, ba) => `Serial (Top)   : ${ba ? 'BA on' : 'BA off'} + ${text}`;

const test_bottom = (t, ba, perform) => test_serial(bottom_target, t, ba, perform);
test_bottom.title = (text, ba) => `Serial (Bottom): ${ba ? 'BA on' : 'BA off'} + ${text}`;

test('First time set', [test_top, test_bottom], BA_OFF, (t, target, state) => {
	t.plan(2);
	const serial = 'x';

	state.on(_EVENTS_._SERIAL_, () => t.fail("'serial' event should not be thrown."));

	t.false(target.set(state, serial));
	t.falsy(target.get(state), serial);
});

test('First time set', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(3);
	const serial = 'x';

	state.on(_EVENTS_._SERIAL_, () => t.pass());

	t.true(target.set(state, serial));
	t.is(target.get(state), serial);
});

test('Set after already set with same serial', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(2);
	const serial = 'x';
	
	target.set(state, serial);

	state.on(_EVENTS_._SERIAL_, () => t.fail("'serial' event should not be thrown."));

	t.false(target.set(state, serial));
	t.is(target.get(state), serial);
});

test('Set + No-Scan', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(2);
	const serial = 'x';

	state.changeState('Mode', _MODE_._NOSCAN_);

	state.on(_EVENTS_._SERIAL_, () => t.fail("'serial' event should not be thrown."));

	t.false(target.set(state, serial));
	t.falsy(target.get(state));
});

test('Set + Bypass', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(2);
	const serial = 'x';

	state.changeState('Mode', _MODE_._BYPASS_);

	state.on(_EVENTS_._SERIAL_, () => t.fail("'serial' event should not be thrown."));

	t.false(target.set(state, serial));
	t.falsy(target.get(state));
});

test('Set + On-the-Fly', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(3);

	const serial = 'x';

	state.changeState('Mode', _MODE_._ONTHEFLY_);

	state.on(_EVENTS_._SERIAL_, () => t.pass());

	t.true(target.set(state, serial));
	t.is(target.get(state), serial);
});

test('Set + prefix mismatch', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(2);
	const prefix = '0';
	const serial = 'x';

	state.changePrefixSuffix(prefix, null);

	state.on(_EVENTS_._SERIAL_, () => t.fail("'serial' event should not be thrown."));

	t.false(target.set(state, serial));
	t.falsy(target.get(state));
});

test('Set + prefix matches', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(3);
	const prefix = '0';
	const serial = prefix + 'x';

	state.changePrefixSuffix(prefix, null);

	state.on(_EVENTS_._SERIAL_, () => t.pass());

	t.true(target.set(state, serial));
	t.is(target.get(state), serial);
});

test('Set + suffix mismatch', [test_top, test_bottom], BA_ON, (t, target, state) => {
	t.plan(2);
	const suffix = '0';
	const serial = 'x';

	state.changePrefixSuffix(null, suffix);

	state.on(_EVENTS_._SERIAL_, () => t.fail("'serial' event should not be thrown."));

	t.false(target.set(state, serial));
	t.falsy(target.get(state));
});

test('Set + suffix matches', [test_top, test_bottom], BA_ON, (t, target, state) => {
	const suffix = '0';
	const serial = 'x' + suffix;

	state.changePrefixSuffix(null, suffix);

	state.on(_EVENTS_._SERIAL_, () => t.pass());

	t.true(target.set(state, serial));
	t.is(target.get(state), serial);
});


// ╓────────────────────────────────────────╖
// ║ Rescanning								║
// ╙────────────────────────────────────────╜

const TEST_RESCAN_TIMEOUT = 0.3 // seconds
const TEST_RESCAN_LIMIT = 2
const TEST_RESCAN_INIT_SERIAL = 'y';

const test_rescan = async (target, t, perform) => {
	const state = new State();
	state.changeRescan(TEST_RESCAN_TIMEOUT, TEST_RESCAN_LIMIT);
	const start = performance.now();
	state.changeState('UpstreamBoardAvailable', true);
	target.set(state, TEST_RESCAN_INIT_SERIAL);
	await perform(t, target, state, start);
};

const test_re_top = (t, perform) => test_rescan(top_target, t, perform);
test_re_top.title = text => `Serial (Top)   : ${text}`;

const test_re_bottom = (t, perform) => test_rescan(bottom_target, t, perform);
test_re_bottom.title = text => `Serial (Bottom): ${text}`;

test('Rescan triggers after given timeout (and not before)', [test_re_top, test_re_bottom], async (t, target, state, start) => {
	t.plan(2);
	state.on(_EVENTS_._DOSCAN_, () => {
		t.true(performance.now() - start > TEST_RESCAN_TIMEOUT)
		t.log(`Rescan triggers at ${performance.now() - start}ms. Timeout: ${TEST_RESCAN_TIMEOUT * 1000}ms.`)
	});

	await snooze(TEST_RESCAN_TIMEOUT * 1000 * 2);
	
	t.is(target.get(state), TEST_RESCAN_INIT_SERIAL);
});

test('Rescan triggers until limit', [test_re_top, test_re_bottom], async (t, target, state, start) => {
	t.plan(1 + TEST_RESCAN_LIMIT);
	state.on(_EVENTS_._DOSCAN_, () => t.pass());

	await snooze(TEST_RESCAN_TIMEOUT * 1000 * (TEST_RESCAN_LIMIT + 1));
	
	t.is(target.get(state), TEST_RESCAN_INIT_SERIAL);
});

test('Rescanned serial is accepted', [test_re_top, test_re_bottom], async (t, target, state, start) => {
	t.plan(2);
	const new_serial = 'x';
	state.on(_EVENTS_._DOSCAN_, () => t.true(target.set(state, new_serial)));

	await snooze(TEST_RESCAN_TIMEOUT * 1000);
	
	t.is(target.get(state), new_serial);
});

test('Rescan stops if board is OK-ed', [test_re_top, test_re_bottom], async (t, target, state, start) => {
	t.plan(1);
	state.on(_EVENTS_._DOSCAN_, () => t.fail(`'${_EVENTS_._DOSCAN_}' event should not be thrown if board is OK-ed before the rescan timeout is reached.`));

	state.changeState('UpstreamBoardOK', true);

	await snooze(TEST_RESCAN_TIMEOUT * 1000);
	
	t.is(target.get(state), TEST_RESCAN_INIT_SERIAL);
});

test('Rescan stops if board is removed', [test_re_top, test_re_bottom], async (t, target, state, start) => {
	t.plan(1);
	state.on(_EVENTS_._DOSCAN_, () => t.fail(`'${_EVENTS_._DOSCAN_}' event should not be thrown if board is removed before the rescan timeout is reached.`));

	state.changeState('UpstreamBoardAvailable', false);

	await snooze(TEST_RESCAN_TIMEOUT);

	t.falsy(target.get(state));
});


// ╓────────────────────────────────────────╖
// ║ changeState							║
// ╙────────────────────────────────────────╜

test('Change: Invalid property', t => {
	const state = new State();
	const invalid_prop_name = 'xxx';

	state.on(_EVENTS_._MODE_, () => t.fail("'changed' event should not be thrown."));

	t.throws(() => {
		state.changeState(invalid_prop_name, true);
	}, { instanceOf: RangeError });

	t.false(invalid_prop_name in state.getState(), 'The invalid property name should not exist in the state instance.');
});

test('Change: Mode - Invalid', t => {
	const state = new State();
	const invalid_val = 'x';

	state.on(_EVENTS_._MODE_, () => t.fail("'changed' event should not be thrown."));

	t.throws(() => {
		state.changeState('Mode', invalid_val);
	 }, { instanceOf: RangeError });
	
	t.not(state.getState().Mode, invalid_val, 'Mode should only contain one of the accepted mode constants.');
});

test('Change: Mode - Same value', t => {

	const state = new State();
	const curr_mode = state.getState().Mode;

	state.on(_EVENTS_._MODE_, () => t.fail("'changed' event should not be thrown."));

	state.changeState('Mode', curr_mode);

	t.is(state.getState().Mode, curr_mode);
});

test('Change: UpstreamBoardAvailable - True', t => {
	t.plan(3);

	const state = new State();

	state.on(_EVENTS_._BOARD_ON_, () => t.pass());
	state.on(_EVENTS_._DOSCAN_, trigger_time_ms => t.is(trigger_time_ms, state._config.TriggerTime * 1000));

	state.changeState('UpstreamBoardAvailable', true);

	t.true(state.getState().UpstreamBoardAvailable);
});

test('Change: UpstreamBoardAvailable - True + No-Scan', t => {
	t.plan(2);

	const state = new State();
	state.changeState('Mode', _MODE_._NOSCAN_);

	state.on(_EVENTS_._BOARD_ON_, () => t.pass());
	state.on(_EVENTS_._DOSCAN_, () => t.fail()); // This event should not trigger

	state.changeState('UpstreamBoardAvailable', true);

	t.true(state.getState().UpstreamBoardAvailable);
});

test('Change: UpstreamBoardAvailable - True + Bypass', t => {
	t.plan(2);

	const state = new State();

	state.changeState('Mode', _MODE_._BYPASS_);

	state.on(_EVENTS_._BOARD_ON_, () => t.pass());
	state.on(_EVENTS_._DOSCAN_, () => t.fail()); // This event should not trigger

	state.changeState('UpstreamBoardAvailable', true);

	t.true(state.getState().UpstreamBoardAvailable);
});

test('Change: UpstreamBoardAvailable - True + serial-top assimilation', t => {
	t.plan(4);

	const state = new State();

	// Set the serial number to assimilate
	const serial = 'x';
	state.setSerialTop(serial);

	state.on(_EVENTS_._BOARD_ON_, () => t.pass());
	state.on(_EVENTS_._SERIAL_, () => t.pass());

	state.changeState('UpstreamBoardAvailable', true);

	t.true(state.getState().UpstreamBoardAvailable);
	t.is(state.getSerials().Top, serial, 'Confirm that the serial was assimilated.');
});

test('Change: UpstreamBoardAvailable - True + serial-bottom assimilation', t => {
	t.plan(4);

	const state = new State();

	// Set the serial number to assimilate
	const serial = 'x';
	state.setSerialBottom(serial);

	state.on(_EVENTS_._BOARD_ON_, () => t.pass());
	state.on(_EVENTS_._SERIAL_, () => t.pass());

	state.changeState('UpstreamBoardAvailable', true);

	t.true(state.getState().UpstreamBoardAvailable);
	t.is(state.getSerials().Bottom, serial, 'Confirm that the serial was assimilated.');
});

test('Change: UpstreamBoardAvailable - False', t => {
	t.plan(2);

	const state = new State();

	state.changeState('UpstreamBoardAvailable', true);

	state.on(_EVENTS_._BOARD_OUST_, () => t.pass());

	state.changeState('UpstreamBoardAvailable', false);

	t.false(state.getState().UpstreamBoardAvailable);
});

test('Change: UpstreamBoardAvailable - False + transferring', t => {
	t.plan(2);

	const state = new State();

	state.changeState('UpstreamBoardAvailable', true);
	state.changeState('Transfer', true);

	state.on(_EVENTS_._BOARD_OFF_, () => t.pass());

	state.changeState('UpstreamBoardAvailable', false);

	t.false(state.getState().UpstreamBoardAvailable);
});

test('Change: UpstreamBoardOK - True', t => {
	t.plan(2);

	const state = new State();

	state.on(_EVENTS_._BOARD_OK_, () => t.pass());

	state.changeState('UpstreamBoardOK', true);

	t.true(state.getState().UpstreamBoardOK);
});

test('Change: UpstreamBoardOK - False', t => {
	t.plan(2);

	const state = new State();

	state.changeState('UpstreamBoardOK', true);

	state.on(_EVENTS_._CHANGED_, () => t.pass());

	state.changeState('UpstreamBoardOK', false)

	t.false(state.getState().UpstreamBoardOK);
});

test('Change: DownstreamReady - True', t => {
	t.plan(2);

	const state = new State();

	state.on(_EVENTS_._CHANGED_, () => t.pass());

	state.changeState('DownstreamReady', true);

	t.true(state.getState().DownstreamReady);
});

test('Change: DownstreamReady - False', t => {
	t.plan(2);

	const state = new State();

	state.changeState('DownstreamReady', true);

	state.on(_EVENTS_._CHANGED_, () => t.pass());

	state.changeState('DownstreamReady', false);

	t.false(state.getState().DownstreamReady);
});

test('Change: DownstreamReady - False + transferring', t => {
	t.plan(2);

	const state = new State();

	state.changeState('DownstreamReady', true);
	state.changeState('Transfer', true);

	state.on(_EVENTS_._TRANSFERRED_, () => t.pass());

	state.changeState('DownstreamReady', false);

	t.false(state.getState().DownstreamReady);
});

test('Change: Transfer - True', t => {
	t.plan(2);

	const state = new State();

	state.on(_EVENTS_._TRANSFERRING_, () => t.pass());

	state.changeState('Transfer', true);

	t.true(state.getState().Transfer);
});

test('Change: Transfer - False', t => {
	t.plan(2);

	const state = new State();

	state.changeState('Transfer', true);

	state.on(_EVENTS_._CHANGED_, () => t.pass());

	state.changeState('Transfer', false);

	t.false(state.getState().Transfer);
});
