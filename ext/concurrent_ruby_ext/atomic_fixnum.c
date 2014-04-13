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
  CAtomicFixnum* atomic;
  VALUE sval = Data_Make_Struct(klass, CAtomicFixnum, NULL, atomic_fixnum_deallocate, atomic);

  pthread_mutex_init(&atomic->mutex, NULL);

  return(sval);
}

void atomic_fixnum_deallocate(void* sval)
{
  CAtomicFixnum* atomic = (CAtomicFixnum*) sval;

  pthread_mutex_destroy(&atomic->mutex);

  free(atomic);
}

VALUE method_atomic_fixnum_initialize(int argc, VALUE* argv, VALUE self) {
  rb_check_arity(argc, 0, 1);
  if (argc == 1) Check_Type(argv[0], T_FIXNUM);

  CAtomicFixnum* atomic;
  Data_Get_Struct(self, CAtomicFixnum, atomic);

  atomic->value = (argc == 1 ? FIX2INT(argv[0]) : 0);
  return(self);
}

VALUE method_atomic_fixnum_value(VALUE self) {
  CAtomicFixnum* atomic;
  VALUE value;

  Data_Get_Struct(self, CAtomicFixnum, atomic);

  pthread_mutex_lock(&atomic->mutex);
  value = INT2FIX(atomic->value);
  pthread_mutex_unlock(&atomic->mutex);

  return(value);
}

VALUE method_atomic_fixnum_value_eq(VALUE self, VALUE value) {
  Check_Type(value, T_FIXNUM);

  CAtomicFixnum* atomic;
  Data_Get_Struct(self, CAtomicFixnum, atomic);

  pthread_mutex_lock(&atomic->mutex);
  atomic->value = FIX2INT(value);
  pthread_mutex_unlock(&atomic->mutex);

  return(value);
}

VALUE method_atomic_fixnum_increment(VALUE self) {
  CAtomicFixnum* atomic;
  Data_Get_Struct(self, CAtomicFixnum, atomic);

  pthread_mutex_lock(&atomic->mutex);
  atomic->value++;
  pthread_mutex_unlock(&atomic->mutex);

  return(INT2FIX(atomic->value));
}

VALUE method_atomic_fixnum_decrement(VALUE self) {
  CAtomicFixnum* atomic;
  Data_Get_Struct(self, CAtomicFixnum, atomic);

  pthread_mutex_lock(&atomic->mutex);
  atomic->value--;
  pthread_mutex_unlock(&atomic->mutex);

  return(INT2FIX(atomic->value));
}

VALUE method_atomic_fixnum_compare_and_set(VALUE self, VALUE rb_expect, VALUE rb_update) {
  Check_Type(rb_expect, T_FIXNUM);
  Check_Type(rb_update, T_FIXNUM);

  CAtomicFixnum* atomic;
  Data_Get_Struct(self, CAtomicFixnum, atomic);

  long expect = FIX2INT(rb_expect);
  long update = FIX2INT(rb_update);
  VALUE retval = Qfalse;

  pthread_mutex_lock(&atomic->mutex);
  if (atomic->value == expect) {
    atomic->value = update;
    retval = Qtrue;
  }
  pthread_mutex_unlock(&atomic->mutex);

  return(retval);
}
