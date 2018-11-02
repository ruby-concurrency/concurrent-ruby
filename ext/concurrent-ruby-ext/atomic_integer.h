#ifndef __ATOMIC_INTEGER_H__
#define __ATOMIC_INTEGER_H__

void atomic_integer_mark(void*);
VALUE atomic_integer_allocate(VALUE);
VALUE method_atomic_integer_initialize(int, VALUE*, VALUE);
VALUE method_atomic_integer_value(VALUE);
VALUE method_atomic_integer_value_set(VALUE, VALUE);
VALUE method_atomic_integer_increment(int, VALUE*, VALUE);
VALUE method_atomic_integer_decrement(int, VALUE*, VALUE);
VALUE method_atomic_integer_compare_and_set(VALUE, VALUE, VALUE);
VALUE method_atomic_integer_update(VALUE);

#endif
