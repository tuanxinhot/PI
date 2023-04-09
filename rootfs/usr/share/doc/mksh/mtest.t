# Catch the most basic failures to run (broken ABI, signals, dietlibc bug,
# select not implemented)
# Failures to pass these leads to the binary being thrown away, if run

name: mtest-builtin
description:
	Minitest: can run a builtin
time-limit: 3
stdin:
	echo foo
expected-stdout:
	foo
---
name: mtest-external
description:
	Minitest: can run an external utility and return
time-limit: 3
stdin:
	echo baz | /usr/bin/tr z r
	echo baz
expected-stdout:
	bar
	baz
---
name: mtest-ascii1
description:
	Part of dollar-quoted-strings
time-limit: 3
stdin:
	printf '<\1\n'|while read x;do while [[ -n $x ]];do typeset -i16 hv=1#${x::1};x=${x:1};echo -n "$hv ";done;done;echo .
expected-stdout:
	16#3c 16#1 .
---
name: mtest-brkcontin
description:
	Check that break and continue work; used by test.sh itself
	and broken at least once on Debian derivate that cannot be named
time-limit: 3
stdin:
	for x in "echo 1" false "echo 2"; do $x && continue; echo 3; break; done; echo 4
expected-stdout:
	1
	3
	4
---
name: mtest-select-works
description:
	Check that we correctly detect our host system has select(2)
	and that it is actually implemented, exported from libc and working
time-limit: 3
stdin:
	print foo | while read -t 1 bar; do print ${bar}bar; done
	sleep 1
	print baz
expected-stdout:
	foobar
	baz
---
