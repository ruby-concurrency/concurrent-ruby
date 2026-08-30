#ifndef CONCURRENT_RUBY_ATOMIC_FIXNUM_H
#define CONCURRENT_RUBY_ATOMIC_FIXNUM_H 1

#include <ruby.h>

VALUE atomic_fixnum_allocate(VALUE klass);
VALUE method_atomic_fixnum_initialize(int argc, VALUE *argv, VALUE self);
VALUE method_atomic_fixnum_value(VALUE self);
VALUE method_atomic_fixnum_value_set(VALUE self, VALUE value);
VALUE method_atomic_fixnum_increment(int argc, VALUE *argv, VALUE self);
VALUE method_atomic_fixnum_decrement(int argc, VALUE *argv, VALUE self);
VALUE method_atomic_fixnum_compare_and_set(VALUE self, VALUE expect, VALUE update);
VALUE method_atomic_fixnum_update(VALUE self);

#endif
