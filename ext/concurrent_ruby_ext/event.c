#include <ruby.h>
#include <ruby/thread.h>
#include <pthread.h>
#include <stdbool.h>

#include "event.h"
#include "helpers.h"

typedef struct event_wait_data {
  CEvent* event;
  VALUE timeout;
  VALUE result;
} EventWaitData;

VALUE event_allocate(VALUE klass) {
  CEvent* event;
  VALUE sval = Data_Make_Struct(klass, CEvent, NULL, event_deallocate, event);

  pthread_mutex_init(&event->mutex, NULL);
  pthread_cond_init(&event->condition, NULL);
  event->set = false;

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
  event->set = 0;

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

  return(NULL);
}

VALUE method_event_set(VALUE self) {
  CEvent* event;

  Data_Get_Struct(self, CEvent, event);

  rb_thread_call_without_gvl2(event_set_without_gvl, (void*)event, RUBY_UBF_PROCESS, NULL);

  return(Qtrue);
}

void* event_try_question_without_gvl(void *data) {
  EventWaitData* ewd = (EventWaitData*) data;

  pthread_mutex_lock(&ewd->event->mutex);

  if (ewd->event->set) {
    ewd->result = Qfalse;
  } else {
    ewd->event->set = true;
    pthread_cond_broadcast(&ewd->event->condition);
    ewd->result = Qtrue;
  }

  pthread_mutex_unlock(&ewd->event->mutex);

  return(NULL);
}

VALUE method_event_try_question(VALUE self) {
  CEvent* event;
  EventWaitData ewd;

  Data_Get_Struct(self, CEvent, event);
  ewd.event = event;

  rb_thread_call_without_gvl2(event_try_question_without_gvl, (void*)&ewd, RUBY_UBF_PROCESS, NULL);

  return(ewd.result);
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
  struct timespec ts;

  pthread_mutex_lock(&ewd->event->mutex);

  if (! ewd->event->set) {

    if (ewd->timeout == Qnil) {

      pthread_cond_wait(&ewd->event->condition, &ewd->event->mutex);

    } else {

      abs_time_from_timeout(NUM2DBL(ewd->timeout), &ts);
      pthread_cond_timedwait(&ewd->event->condition, &ewd->event->mutex, &ts);
    }
  }

  ewd->result = ewd->event->set ? Qtrue : Qfalse;
  pthread_mutex_unlock(&ewd->event->mutex);

  return(NULL);
}

VALUE method_event_wait(int argc, VALUE* argv, VALUE self) {
  CEvent* event;
  EventWaitData ewd;

  rb_check_arity(argc, 0, 1);

  Data_Get_Struct(self, CEvent, event);
  ewd.event = event;
  ewd.timeout = (argc == 0 ? Qnil : argv[0]);
  ewd.result = Qtrue;

  rb_thread_call_without_gvl2(event_wait_without_gvl, (void*)&ewd, RUBY_UBF_PROCESS, NULL);

  return(ewd.result);
}
