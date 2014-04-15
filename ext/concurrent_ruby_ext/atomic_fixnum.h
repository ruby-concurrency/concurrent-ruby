#ifndef __ATOMIC_FIXNUM_H__
#define __ATOMIC_FIXNUM_H__

typedef struct atomic_fixnum {
  long value;
  //pthread_mutex_t mutex;
} CAtomicFixnum;

VALUE atomic_fixnum_allocate(VALUE);
void atomic_fixnum_deallocate(void*);
VALUE method_atomic_fixnum_initialize(int, VALUE*, VALUE);
VALUE method_atomic_fixnum_value(VALUE);
VALUE method_atomic_fixnum_value_eq(VALUE, VALUE);
VALUE method_atomic_fixnum_increment(VALUE);
VALUE method_atomic_fixnum_decrement(VALUE);
VALUE method_atomic_fixnum_compare_and_set(VALUE, VALUE, VALUE);

#endif
