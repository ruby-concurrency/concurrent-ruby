#include <ruby.h>
#include <pthread.h>

typedef struct atomic_fixnum {
  long value;
  pthread_mutex_t mutex;
} CAtomicFixnum;

// forward declarations
void atomic_fixnum_deallocate(void*);

/////////////////////////////////////////////////////////////////////
// definitions

VALUE atomic_fixnum_allocate(VALUE klass)
{
  CAtomicFixnum* sval = malloc(sizeof(CAtomicFixnum));
  return Data_Wrap_Struct(klass, NULL, atomic_fixnum_deallocate, sval);
  // CAtomicFixnum* sval;
  // return Data_Make_Struct(klass, CAtomicFixnum, NULL, atomic_fixnum_deallocate, sval);
}

void atomic_fixnum_deallocate(void* sval)
{
  free((CAtomicFixnum*) sval);
}

VALUE method_atomic_fixnum_initialize(int argc, VALUE* argv, VALUE self) {
  rb_check_arity(argc, 0, 1);
  if (argc == 1) Check_Type(argv[0], T_FIXNUM);

  CAtomicFixnum* sval;
  Data_Get_Struct(self, CAtomicFixnum, sval);

  sval->value = (argc == 1 ? FIX2INT(argv[0]) : 0);
  return(self);
}

VALUE method_atomic_fixnum_value(VALUE self) {
  CAtomicFixnum* sval;
  Data_Get_Struct(self, CAtomicFixnum, sval);
  return(INT2FIX(sval->value));
}

VALUE method_atomic_fixnum_value_eq(VALUE self, VALUE value) {
  Check_Type(value, T_FIXNUM);
  CAtomicFixnum* sval;
  Data_Get_Struct(self, CAtomicFixnum, sval);
  sval->value = FIX2INT(value);
  return(value);
}

VALUE method_atomic_fixnum_increment(VALUE self) {
  CAtomicFixnum* sval;
  Data_Get_Struct(self, CAtomicFixnum, sval);
  sval->value++;
  return(INT2FIX(sval->value));
}

VALUE method_atomic_fixnum_decrement(VALUE self) {
  CAtomicFixnum* sval;
  Data_Get_Struct(self, CAtomicFixnum, sval);
  sval->value--;
  return(INT2FIX(sval->value));
}

VALUE method_atomic_fixnum_compare_and_set(VALUE self, VALUE rb_expect, VALUE rb_update) {
  Check_Type(rb_expect, T_FIXNUM);
  Check_Type(rb_update, T_FIXNUM);

  CAtomicFixnum* sval;
  Data_Get_Struct(self, CAtomicFixnum, sval);

  long expect = FIX2INT(rb_expect);
  long update = FIX2INT(rb_update);
  VALUE retval = Qfalse;

  if (sval->value == expect) {
    sval->value = update;
    retval = Qtrue;
  }

  return(retval);
}
