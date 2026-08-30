#include "atomic_boolean.h"
#include "atomic_reference.h"

CR_DEFINE_ATOMIC_DATA_TYPE(atomic_boolean_type, "Concurrent::CAtomicBoolean");

VALUE atomic_boolean_allocate(VALUE klass) {
  cr_atomic_t *atomic;
  VALUE obj = TypedData_Make_Struct(klass, cr_atomic_t, &atomic_boolean_type, atomic);
  RB_OBJ_WRITE(obj, &atomic->value, Qfalse);
  return obj;
}

VALUE method_atomic_boolean_initialize(int argc, VALUE *argv, VALUE self) {
  cr_atomic_t *atomic;
  VALUE value = Qfalse;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_boolean_type, atomic);

  rb_check_arity(argc, 0, 1);
  if (argc == 1) value = TRUTHY(argv[0]);
  RB_OBJ_WRITE(self, &atomic->value, value);
  return self;
}

VALUE method_atomic_boolean_value(VALUE self) {
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_boolean_type, atomic);
  return cr_atomic_value_load(atomic);
}

VALUE method_atomic_boolean_value_set(VALUE self, VALUE value) {
  cr_atomic_t *atomic;
  VALUE new_value = TRUTHY(value);
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_boolean_type, atomic);
  cr_atomic_value_set(atomic, new_value);
  RB_OBJ_WRITTEN(self, Qundef, new_value);
  return new_value;
}

VALUE method_atomic_boolean_true_question(VALUE self) {
  return method_atomic_boolean_value(self);
}

VALUE method_atomic_boolean_false_question(VALUE self) {
  return method_atomic_boolean_value(self) == Qfalse ? Qtrue : Qfalse;
}

VALUE method_atomic_boolean_make_true(VALUE self) {
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_boolean_type, atomic);

  if (cr_atomic_value_cas(atomic, Qfalse, Qtrue) == Qfalse) {
    RB_OBJ_WRITTEN(self, Qfalse, Qtrue);
    return Qtrue;
  }
  return Qfalse;
}

VALUE method_atomic_boolean_make_false(VALUE self) {
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_boolean_type, atomic);

  if (cr_atomic_value_cas(atomic, Qtrue, Qfalse) == Qtrue) {
    RB_OBJ_WRITTEN(self, Qtrue, Qfalse);
    return Qtrue;
  }
  return Qfalse;
}
