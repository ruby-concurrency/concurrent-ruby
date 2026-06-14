#include "atomic_reference.h"

VALUE cr_atomic_value_load(const cr_atomic_t *atomic) {
#if defined(RUBY_ATOMIC_PTR_LOAD)
  VALUE *slot = (VALUE *)&atomic->value;
  return (VALUE)RUBY_ATOMIC_PTR_LOAD(*slot);
#elif defined(__GNUC__) || defined(__clang__)
  return __atomic_load_n(&atomic->value, __ATOMIC_SEQ_CST);
#else
  /* Aligned word-sized reads are atomic on every platform Ruby supports. */
  return atomic->value;
#endif
}

VALUE cr_atomic_value_cas(cr_atomic_t *atomic, VALUE oldval, VALUE newval) {
#if defined(RUBY_ATOMIC_VALUE_CAS)
  return RUBY_ATOMIC_VALUE_CAS(atomic->value, oldval, newval);
#elif defined(__GNUC__) || defined(__clang__)
  VALUE expected = oldval;
  __atomic_compare_exchange_n(&atomic->value, &expected, newval, 0,
                              __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
  return expected;
#else
#error "concurrent-ruby-ext requires RUBY_ATOMIC_VALUE_CAS or GCC/Clang atomic builtins"
#endif
}

void cr_atomic_mark(void *ptr) {
  cr_atomic_t *atomic = (cr_atomic_t *)ptr;
#ifdef CR_GC_COMPACTION
  rb_gc_mark_movable(atomic->value);
#else
  rb_gc_mark(atomic->value);
#endif
}

void cr_atomic_free(void *ptr) {
  xfree(ptr);
}

size_t cr_atomic_memsize(const void *ptr) {
  (void)ptr;
  return sizeof(cr_atomic_t);
}

#ifdef CR_GC_COMPACTION
void cr_atomic_compact(void *ptr) {
  cr_atomic_t *atomic = (cr_atomic_t *)ptr;
  atomic->value = rb_gc_location(atomic->value);
}
#endif

static const rb_data_type_t ir_type = {
  .wrap_struct_name = "Concurrent::CAtomicReference",
  .function = {
    .dmark = cr_atomic_mark,
    .dfree = cr_atomic_free,
    .dsize = cr_atomic_memsize,
#ifdef CR_GC_COMPACTION
    .dcompact = cr_atomic_compact,
#endif
  },
  .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};

VALUE ir_alloc(VALUE klass) {
  cr_atomic_t *atomic;
  VALUE obj = TypedData_Make_Struct(klass, cr_atomic_t, &ir_type, atomic);
  RB_OBJ_WRITE(obj, &atomic->value, Qnil);
  return obj;
}

VALUE ir_initialize(int argc, VALUE *argv, VALUE self) {
  VALUE value = Qnil;
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &ir_type, atomic);

  if (rb_scan_args(argc, argv, "01", &value) == 1) {
    value = argv[0];
  }
  RB_OBJ_WRITE(self, &atomic->value, value);
  return Qnil;
}

VALUE ir_get(VALUE self) {
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &ir_type, atomic);
  return cr_atomic_value_load(atomic);
}

VALUE ir_set(VALUE self, VALUE new_value) {
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &ir_type, atomic);
  RB_OBJ_WRITE(self, &atomic->value, new_value);
  return new_value;
}

VALUE ir_get_and_set(VALUE self, VALUE new_value) {
  cr_atomic_t *atomic;
  VALUE old_value;
  TypedData_Get_Struct(self, cr_atomic_t, &ir_type, atomic);

  for (;;) {
    old_value = cr_atomic_value_load(atomic);
    if (cr_atomic_value_cas(atomic, old_value, new_value) == old_value) {
      RB_OBJ_WRITTEN(self, old_value, new_value);
      return old_value;
    }
  }
}

VALUE ir_compare_and_set(VALUE self, VALUE expect_value, VALUE new_value) {
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &ir_type, atomic);

  if (cr_atomic_value_cas(atomic, expect_value, new_value) == expect_value) {
    RB_OBJ_WRITTEN(self, expect_value, new_value);
    return Qtrue;
  }
  return Qfalse;
}
