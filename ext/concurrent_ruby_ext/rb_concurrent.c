#include <ruby.h>

#include "atomic_boolean.h"
#include "atomic_fixnum.h"
#include "event.h"

// module and class definitions
static VALUE rb_mConcurrent;
static VALUE rb_cAtomicBoolean;
static VALUE rb_cAtomicFixnum;
static VALUE rb_cEvent;

void Init_concurrent_ruby_ext() {

  // define modules and classes
  rb_mConcurrent = rb_define_module("Concurrent");
  rb_cAtomicBoolean = rb_define_class_under(rb_mConcurrent, "CAtomicBoolean", rb_cObject);
  rb_cAtomicFixnum = rb_define_class_under(rb_mConcurrent, "CAtomicFixnum", rb_cObject);
  rb_cEvent = rb_define_class_under(rb_mConcurrent, "CEvent", rb_cObject);

  // constants
  rb_define_const(rb_mConcurrent, "MAX_INT", INT_MAX);
  rb_define_const(rb_mConcurrent, "MAX_INT", LONG_MAX);

  // CAtomicBoolean
  rb_define_alloc_func(rb_cAtomicBoolean, atomic_boolean_allocate);
  rb_define_method(rb_cAtomicBoolean, "initialize", method_atomic_boolean_initialize, -1);
  rb_define_method(rb_cAtomicBoolean, "value", method_atomic_boolean_value, 0);
  rb_define_method(rb_cAtomicBoolean, "value=", method_atomic_boolean_value_set, 1);
  rb_define_method(rb_cAtomicBoolean, "true?", method_atomic_boolean_true_question, 0);
  rb_define_method(rb_cAtomicBoolean, "false?", method_atomic_boolean_false_question, 0);
  rb_define_method(rb_cAtomicBoolean, "make_true", method_atomic_boolean_make_true, 0);
  rb_define_method(rb_cAtomicBoolean, "make_false", method_atomic_boolean_make_false, 0);

  // CAtomicFixnum
  rb_define_alloc_func(rb_cAtomicFixnum, atomic_fixnum_allocate);
  rb_define_method(rb_cAtomicFixnum, "initialize", method_atomic_fixnum_initialize, -1);
  rb_define_method(rb_cAtomicFixnum, "value", method_atomic_fixnum_value, 0);
  rb_define_method(rb_cAtomicFixnum, "value=", method_atomic_fixnum_value_set, 1);
  rb_define_method(rb_cAtomicFixnum, "increment", method_atomic_fixnum_increment, 0);
  rb_define_method(rb_cAtomicFixnum, "decrement", method_atomic_fixnum_decrement, 0);
  rb_define_method(rb_cAtomicFixnum, "compare_and_set", method_atomic_fixnum_compare_and_set, 2);
  rb_define_alias(rb_cAtomicFixnum, "up", "increment");
  rb_define_alias(rb_cAtomicFixnum, "down", "decrement");

  // CEvent
  rb_define_alloc_func(rb_cEvent, event_allocate);
  rb_define_method(rb_cEvent, "initialize", method_event_initialize, 0);
  rb_define_method(rb_cEvent, "set?", method_event_set_question, 0);
  rb_define_method(rb_cEvent, "set", method_event_set, 0);
  rb_define_method(rb_cEvent, "try?", method_event_try_question, 0);
  rb_define_method(rb_cEvent, "reset", method_event_reset, 0);
  rb_define_method(rb_cEvent, "wait", method_event_wait, -1);
}
