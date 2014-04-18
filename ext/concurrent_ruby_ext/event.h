#ifndef __EVENT_H__
#define __EVENT_H__

#include <stdbool.h>
#include <pthread.h>

typedef struct event {
  bool set;
  pthread_mutex_t mutex;
  pthread_cond_t condition;
} CEvent;

typedef struct event_wait_data {
  CEvent* event;
  VALUE timeout;
  VALUE result;
} EventWaitData;

VALUE event_allocate(VALUE);
void event_deallocate(void*);
VALUE method_event_initialize(VALUE);
VALUE method_event_set_question(VALUE);
VALUE method_event_set(VALUE);
VALUE method_event_try_question(VALUE);
VALUE method_event_reset(VALUE);
VALUE method_event_wait(int, VALUE*, VALUE);

#endif
