#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void (*saved_handlerInChapel)();

static
void handler(int sigNum, siginfo_t *info, void *ctx) {
  (*saved_handlerInChapel)();
}

void installHandler(int sigNum, void (*handlerInChapel)(void)) {
  saved_handlerInChapel = handlerInChapel;
  struct sigaction act;
  act.sa_sigaction = handler;
  sigemptyset(&act.sa_mask);
  act.sa_flags = SA_SIGINFO;
  if (sigaction(sigNum, &act, NULL) != 0) {
    perror("sigaction()");
    exit(1);
  }
}
