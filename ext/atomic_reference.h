#ifndef __ATOMIC_REFERENCE_H__
#define __ATOMIC_REFERENCE_H__

void ir_mark(void*);
VALUE ir_alloc(VALUE);
VALUE ir_initialize(int, VALUE*, VALUE);
VALUE ir_get(VALUE);
VALUE ir_set(VALUE, VALUE);
VALUE ir_get_and_set(VALUE, VALUE);
VALUE ir_compare_and_set(volatile VALUE, VALUE, VALUE);

#endif
