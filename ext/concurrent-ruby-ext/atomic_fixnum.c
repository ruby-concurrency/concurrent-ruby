#include "atomic_fixnum.h"
#include "atomic_reference.h"

static const rb_data_type_t atomic_fixnum_type = {
  .wrap_struct_name = "Concurrent::CAtomicFixnum",
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

VALUE atomic_fixnum_allocate(VALUE klass) {
  cr_atomic_t *atomic;
  VALUE obj = TypedData_Make_Struct(klass, cr_atomic_t, &atomic_fixnum_type, atomic);
  RB_OBJ_WRITE(obj, &atomic->value, LL2NUM(0));
  return obj;
}

VALUE method_atomic_fixnum_initialize(int argc, VALUE *argv, VALUE self) {
  cr_atomic_t *atomic;
  VALUE value = LL2NUM(0);
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_fixnum_type, atomic);

  rb_check_arity(argc, 0, 1);
  if (argc == 1) {
    Check_Type(argv[0], T_FIXNUM);
    value = argv[0];
  }
  RB_OBJ_WRITE(self, &atomic->value, value);
  return self;
}

VALUE method_atomic_fixnum_value(VALUE self) {
  cr_atomic_t *atomic;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_fixnum_type, atomic);
  return cr_atomic_value_load(atomic);
}

VALUE method_atomic_fixnum_value_set(VALUE self, VALUE value) {
  cr_atomic_t *atomic;
  Check_Type(value, T_FIXNUM);
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_fixnum_type, atomic);
  RB_OBJ_WRITE(self, &atomic->value, value);
  return value;
}

VALUE method_atomic_fixnum_increment(int argc, VALUE *argv, VALUE self) {
  cr_atomic_t *atomic;
  long long delta = 1;
  long long value;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_fixnum_type, atomic);

  rb_check_arity(argc, 0, 1);
  if (argc == 1) {
    Check_Type(argv[0], T_FIXNUM);
    delta = NUM2LL(argv[0]);
  }
  value = NUM2LL(cr_atomic_value_load(atomic));
  return method_atomic_fixnum_value_set(self, LL2NUM(value + delta));
}

VALUE method_atomic_fixnum_decrement(int argc, VALUE *argv, VALUE self) {
  cr_atomic_t *atomic;
  long long delta = 1;
  long long value;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_fixnum_type, atomic);

  rb_check_arity(argc, 0, 1);
  if (argc == 1) {
    Check_Type(argv[0], T_FIXNUM);
    delta = NUM2LL(argv[0]);
  }
  value = NUM2LL(cr_atomic_value_load(atomic));
  return method_atomic_fixnum_value_set(self, LL2NUM(value - delta));
}

VALUE method_atomic_fixnum_compare_and_set(VALUE self, VALUE expect, VALUE update) {
  cr_atomic_t *atomic;
  Check_Type(expect, T_FIXNUM);
  Check_Type(update, T_FIXNUM);
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_fixnum_type, atomic);

  if (cr_atomic_value_cas(atomic, expect, update) == expect) {
    RB_OBJ_WRITTEN(self, expect, update);
    return Qtrue;
  }
  return Qfalse;
}

VALUE method_atomic_fixnum_update(VALUE self) {
  cr_atomic_t *atomic;
  VALUE old_value, new_value;
  TypedData_Get_Struct(self, cr_atomic_t, &atomic_fixnum_type, atomic);

  for (;;) {
    old_value = cr_atomic_value_load(atomic);
    new_value = rb_yield(old_value);
    if (cr_atomic_value_cas(atomic, old_value, new_value) == old_value) {
      RB_OBJ_WRITTEN(self, old_value, new_value);
      return new_value;
    }
  }
}
