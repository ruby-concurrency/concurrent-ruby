#include "atomic_reference.h"

void cr_atomic_mark(void *ptr) {
  cr_atomic_t *atomic = (cr_atomic_t *)ptr;
#ifdef CR_GC_COMPACTION
  rb_gc_mark_movable(atomic->value);
#else
  rb_gc_mark(atomic->value);
#endif
}

size_t cr_atomic_memsize(const void *ptr) {
  (void)ptr;
  return sizeof(cr_atomic_t);
}

#ifdef CR_GC_COMPACTION
void cr_atomic_compact(void *ptr) {
  /* Stop-the-world; the reference identity is unchanged so neither an atomic
   * store nor a write barrier is required. */
  cr_atomic_t *atomic = (cr_atomic_t *)ptr;
  atomic->value = rb_gc_location(atomic->value);
}
#endif

CR_DEFINE_ATOMIC_DATA_TYPE(ir_type, "Concurrent::CAtomicReference");

VALUE ir_alloc(VALUE klass) {
  cr_atomic_t *atomic;
  VALUE obj = TypedData_Make_Struct(klass, cr_atomic_t, &ir_type, atomic);
  RB_OBJ_WRITE(obj, &atomic->value, Qnil);
  return obj;
}

VALUE ir_initialize(int argc, VALUE *argv, VALUE self) {
  cr_atomic_t *atomic;
  VALUE value = Qnil;
  TypedData_Get_Struct(self, cr_atomic_t, &ir_type, atomic);

  rb_scan_args(argc, argv, "01", &value);
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
  cr_atomic_value_set(atomic, new_value);
  RB_OBJ_WRITTEN(self, Qundef, new_value);
  return new_value;
}

VALUE ir_get_and_set(VALUE self, VALUE new_value) {
  cr_atomic_t *atomic;
  VALUE old_value;
  TypedData_Get_Struct(self, cr_atomic_t, &ir_type, atomic);
  old_value = cr_atomic_value_exchange(atomic, new_value);
  RB_OBJ_WRITTEN(self, old_value, new_value);
  return old_value;
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
