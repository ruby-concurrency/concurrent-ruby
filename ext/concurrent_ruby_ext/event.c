#include <ruby.h>
#include <ruby/thread.h>
#include <sys/time.h>

#include <stdio.h>

#include "event.h"

// for converting timeout (float seconds) to absolute system time
#define NANO 1000000000
#define MICRO 1000000

VALUE event_allocate(VALUE klass) {
  CEvent* event;
  VALUE sval = Data_Make_Struct(klass, CEvent, NULL, event_deallocate, event);

  pthread_mutex_init(&event->mutex, NULL);
  pthread_cond_init(&event->condition, NULL);

  return(sval);
}

void event_deallocate(void* sval) {
  CEvent* event = (CEvent*) sval;

  pthread_cond_destroy(&event->condition);
  pthread_mutex_destroy(&event->mutex);

  free(event);
}

VALUE method_event_initialize(VALUE self) { 
  CEvent* event;

  Data_Get_Struct(self, CEvent, event);
  event->set = false;

  return self;
}

VALUE method_event_set_question(VALUE self) {
  CEvent* event;
  VALUE value;

  Data_Get_Struct(self, CEvent, event);

  pthread_mutex_lock(&event->mutex);
  value = event->set ? Qtrue : Qfalse;
  pthread_mutex_unlock(&event->mutex);

  return(value);
}

void* event_set_without_gvl(void *data) {
  CEvent* event = (CEvent*) data;

  pthread_mutex_lock(&event->mutex);

  if (! event->set) {
    event->set = true;
    pthread_cond_broadcast(&event->condition);
  }

  pthread_mutex_unlock(&event->mutex);

  return(data);
}

VALUE method_event_set(VALUE self) {
  CEvent* event;

  Data_Get_Struct(self, CEvent, event);

  rb_thread_call_without_gvl(event_set_without_gvl, (void*)&event, NULL, NULL);

  return(Qtrue);
}

VALUE method_event_try_question(VALUE self) {
  CEvent* event;
  VALUE value = Qfalse;

  Data_Get_Struct(self, CEvent, event);

  pthread_mutex_lock(&event->mutex);

  if (! event->set) {
    event->set = true;
    pthread_cond_broadcast(&event->condition);
    value = Qtrue;
  }

  pthread_mutex_unlock(&event->mutex);

  return(value);
}

VALUE method_event_reset(VALUE self) {
  CEvent* event;

  Data_Get_Struct(self, CEvent, event);

  pthread_mutex_lock(&event->mutex);
  event->set = false;
  pthread_mutex_unlock(&event->mutex);

  return(Qtrue);
}

void* event_wait_without_gvl(void *data) {
  EventWaitData* ewd = (EventWaitData*) data;

  int rc;
  struct timespec ts;
  struct timeval tp;

  double timeout;
  int seconds;
  long nanos;

  pthread_mutex_lock(&ewd->event->mutex);

  if (! ewd->event->set) {

    if (ewd->timeout == Qnil) {

      pthread_cond_wait(&ewd->event->condition, &ewd->event->mutex);

    } else {

      timeout = NUM2DBL(ewd->timeout);
      seconds = (int) timeout;
      nanos = (timeout - seconds) * MICRO * 1000;

      rc = gettimeofday(&tp, NULL);
      ts.tv_sec  = tp.tv_sec;
      ts.tv_nsec = tp.tv_usec * 1000;
      ts.tv_sec += seconds;
      if (ts.tv_nsec >= NANO) {
        ts.tv_nsec -= NANO;
        ts.tv_sec += 1;
      }

      pthread_cond_timedwait(&ewd->event->condition, &ewd->event->mutex, &ts);
    }

    ewd->result = ewd->event->set ? Qtrue : Qfalse;
  }

  pthread_mutex_unlock(&ewd->event->mutex);

  return(data);
}

VALUE method_event_wait(int argc, VALUE* argv, VALUE self) {
  CEvent* event;
  EventWaitData ewd;

  rb_check_arity(argc, 0, 1);
  if (argc == 1) Check_Type(argv[0], T_FIXNUM);

  Data_Get_Struct(self, CEvent, event);
  ewd.event = event;
  ewd.timeout = (argc == 0 ? Qnil : argv[0]);
  ewd.result = Qtrue;

  rb_thread_call_without_gvl(event_wait_without_gvl, (void*)&ewd, NULL, NULL);

  return(ewd.result);
}
