#include <ruby.h>

static void ir_mark(void *value) {
  rb_gc_mark_maybe((VALUE)value);
}

static VALUE ir_alloc(VALUE klass) {
  return rb_data_object_alloc(klass, (void *)Qnil, ir_mark, NULL);
}

static VALUE ir_initialize(VALUE self, VALUE value) {
  DATA_PTR(self) = (void *)value;
  return Qnil;
}

static VALUE ir_get(VALUE self) {
  return (VALUE)DATA_PTR(self);
}

static VALUE ir_set(VALUE self, VALUE new_value) {
  DATA_PTR(self) = (void *)new_value;
  return new_value;
}

static VALUE ir_get_and_set(VALUE self, VALUE new_value) {
  VALUE old_value;
  old_value = (VALUE)DATA_PTR(self);
  DATA_PTR(self) = (void *)new_value;
  return old_value;
}

static VALUE ir_compare_and_set(volatile VALUE self, VALUE expect_value, VALUE new_value) {
#if __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ >= 1050
  if (OSAtomicCompareAndSwap64(expect_value, new_value, &DATA_PTR(self))) {
    return Qtrue;
  }
#elif (__GNUC__ * 10000 + __GNUC_MINOR__ * 100 + __GNUC_PATCHLEVEL__) > 40100
  if (__sync_bool_compare_and_swap(&DATA_PTR(self), expect_value, new_value)) {
    return Qtrue;
  }
#else
# error No CAS operation available for this platform
#endif
  return Qfalse;
}

void Init_atomic_reference() {
  VALUE cAtomic;
  VALUE cInternalReference;

  cAtomic = rb_const_get(rb_cObject, rb_intern("Atomic"));
  cInternalReference = rb_define_class_under(cAtomic, "InternalReference",
                                             rb_cObject);

  rb_define_alloc_func(cInternalReference, ir_alloc);

  rb_define_method(cInternalReference, "initialize", ir_initialize, 1);
  rb_define_method(cInternalReference, "get", ir_get, 0);
  rb_define_method(cInternalReference, "set", ir_set, 1);
  rb_define_method(cInternalReference, "get_and_set", ir_get_and_set, 1);
  rb_define_method(cInternalReference, "compare_and_set", ir_compare_and_set, 2);
}
