use Time;

config const sigNum = 2; // SIGINT (CTRL/C)

config const maxRunTime = 30.0; // seconds

var calledChapelHandler = false;

extern proc installHandler(sigNum: int, myHandler: c_fn_ptr);
installHandler(sigNum, c_ptrTo(handlerInChapel));

const iterSleepTime = 0.1;
var totalSleepTime = 0.0;
while !calledChapelHandler && totalSleepTime < maxRunTime {
  sleep(iterSleepTime);
  totalSleepTime += iterSleepTime;
}

writeln('I ',
        if calledChapelHandler then 'saw' else 'did not see',
        ' the signal.');


// We have no idea of the state of the program when we arrive here, so
// we can't do I/O or anything that might allocate memory or whatnot.
// So, just set a global.
proc handlerInChapel() {
  calledChapelHandler = true;
}
