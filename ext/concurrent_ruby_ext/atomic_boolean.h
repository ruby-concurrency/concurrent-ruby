#ifndef __ATOMIC_BOOLEAN_H__
#define __ATOMIC_BOOLEAN_H__

#ifdef __ATOMIC_SEQ_CST
#define __USE_GCC_ATOMIC
#endif

#ifndef __USE_GCC_ATOMIC
#include <pthread.h>
#endif

#include <stdbool.h>

#define RUBY2BOOL(value)(! (value == Qfalse || value == Qnil))
#define BOOL2RUBY(value)(value == true ? Qtrue : Qfalse)

typedef struct atomic_boolean {
  bool value;
#ifndef __USE_GCC_ATOMIC
  pthread_mutex_t mutex;
#endif
} CAtomicBoolean;

VALUE atomic_boolean_allocate(VALUE);
void atomic_boolean_deallocate(void*);
VALUE method_atomic_boolean_initialize(int, VALUE*, VALUE);
VALUE method_atomic_boolean_value(VALUE);
VALUE method_atomic_boolean_value_set(VALUE, VALUE);
VALUE method_atomic_boolean_true_question(VALUE);
VALUE method_atomic_boolean_false_question(VALUE);
VALUE method_atomic_boolean_make_true(VALUE);
VALUE method_atomic_boolean_make_false(VALUE);

#endif
