#ifndef CONCURRENT_RUBY_ATOMIC_BOOLEAN_H
#define CONCURRENT_RUBY_ATOMIC_BOOLEAN_H 1

#include <ruby.h>

#define TRUTHY(value) (((value) == Qfalse || (value) == Qnil) ? Qfalse : Qtrue)

VALUE atomic_boolean_allocate(VALUE klass);
VALUE method_atomic_boolean_initialize(int argc, VALUE *argv, VALUE self);
VALUE method_atomic_boolean_value(VALUE self);
VALUE method_atomic_boolean_value_set(VALUE self, VALUE value);
VALUE method_atomic_boolean_true_question(VALUE self);
VALUE method_atomic_boolean_false_question(VALUE self);
VALUE method_atomic_boolean_make_true(VALUE self);
VALUE method_atomic_boolean_make_false(VALUE self);

#endif
