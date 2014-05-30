#include <ruby.h>
#include <sys/time.h>

// for converting timeout (float seconds) to absolute system time
#define NANO 1000000000
#define MICRO 1000000

void abs_time_from_timeout(double timeout, struct timespec* ts) {

  struct timeval tp;

  int seconds;
  long nanos;

  seconds = (int) timeout;
  nanos = (timeout - seconds) * MICRO * 1000;

  gettimeofday(&tp, NULL);
  ts->tv_sec = tp.tv_sec + seconds;
  ts->tv_nsec = (tp.tv_usec * 1000) + nanos;
  if (ts->tv_nsec >= NANO) {
    ts->tv_nsec -= NANO;
    ts->tv_sec += 1;
  }
}

void Check_Boolean(VALUE value) {
  VALUE type = TYPE(value);

  if (type != T_TRUE && type != T_FALSE) {
    rb_raise(rb_eTypeError, "must be a boolean");
  }
}
