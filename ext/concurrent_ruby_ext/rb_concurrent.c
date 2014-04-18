#include <ruby.h>

#include "atomic_fixnum.h"

// module and class definitions
static VALUE rb_mConcurrent;
static VALUE rb_cAtomicFixnum;

void Init_concurrent_ruby_ext() {

  // define modules and classes
  rb_mConcurrent = rb_define_module("Concurrent");
  rb_cAtomicFixnum = rb_define_class_under(rb_mConcurrent, "CAtomicFixnum", rb_cObject);

  // constants
  rb_define_const(rb_mConcurrent, "MAX_INT", INT_MAX);
  rb_define_const(rb_mConcurrent, "MAX_INT", LONG_MAX);

  // CAtomicFixnum
  rb_define_alloc_func(rb_cAtomicFixnum, atomic_fixnum_allocate);
  rb_define_method(rb_cAtomicFixnum, "initialize", method_atomic_fixnum_initialize, -1);
  rb_define_method(rb_cAtomicFixnum, "value", method_atomic_fixnum_value, 0);
  rb_define_method(rb_cAtomicFixnum, "value=", method_atomic_fixnum_value_eq, 1);
  rb_define_method(rb_cAtomicFixnum, "increment", method_atomic_fixnum_increment, 0);
  rb_define_method(rb_cAtomicFixnum, "decrement", method_atomic_fixnum_decrement, 0);
  rb_define_method(rb_cAtomicFixnum, "compare_and_set", method_atomic_fixnum_compare_and_set, 2);
  rb_define_alias(rb_cAtomicFixnum, "up", "increment");
  rb_define_alias(rb_cAtomicFixnum, "down", "decrement");
}
