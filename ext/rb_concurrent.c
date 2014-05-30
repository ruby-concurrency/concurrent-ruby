#include <ruby.h>

#include "atomic_reference.h"

// module and class definitions

static VALUE rb_mConcurrent;
static VALUE rb_cAtomic;

// Init_concurrent_cruby

void Init_concurrent_cruby() {

  // define modules and classes
  rb_mConcurrent = rb_define_module("Concurrent");
  rb_cAtomic = rb_define_class_under(rb_mConcurrent, "Atomic", rb_cObject);

  // CAtomic
  rb_define_alloc_func(rb_cAtomic, ir_alloc);
  rb_define_method(rb_cAtomic, "initialize", ir_initialize, -1);
  rb_define_method(rb_cAtomic, "get", ir_get, 0);
  rb_define_method(rb_cAtomic, "value", ir_get, 0);
  rb_define_method(rb_cAtomic, "set", ir_set, 1);
  rb_define_method(rb_cAtomic, "value=", ir_set, 1);
  rb_define_method(rb_cAtomic, "get_and_set", ir_get_and_set, 1);
  rb_define_method(rb_cAtomic, "swap", ir_get_and_set, 1);
  rb_define_method(rb_cAtomic, "compare_and_set", ir_compare_and_set, 2);
  rb_define_method(rb_cAtomic, "compare_and_swap", ir_compare_and_set, 2);
}
