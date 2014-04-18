#include <ruby.h>
#include <stdbool.h>

#include "atomic_fixnum.h"

// http://gcc.gnu.org/onlinedocs/gcc-4.7.1/gcc/_005f_005fatomic-Builtins.html

VALUE atomic_fixnum_allocate(VALUE klass) {
  CAtomicFixnum* atomic;
  VALUE sval = Data_Make_Struct(klass, CAtomicFixnum, NULL, atomic_fixnum_deallocate, atomic);

#ifndef __USE_GCC_ATOMIC
  pthread_mutex_init(&atomic->mutex, NULL);
#endif

  return(sval);
}

void atomic_fixnum_deallocate(void* sval) {
  CAtomicFixnum* atomic = (CAtomicFixnum*) sval;

#ifndef __USE_GCC_ATOMIC
  pthread_mutex_destroy(&atomic->mutex);
#endif

  free(atomic);
}

VALUE method_atomic_fixnum_initialize(int argc, VALUE* argv, VALUE self) {
  CAtomicFixnum* atomic;

  rb_check_arity(argc, 0, 1);
  if (argc == 1) Check_Type(argv[0], T_FIXNUM);

  Data_Get_Struct(self, CAtomicFixnum, atomic);

  atomic->value = (argc == 1 ? FIX2INT(argv[0]) : 0);
  return(self);
}

VALUE method_atomic_fixnum_value(VALUE self) {
  CAtomicFixnum* atomic;
  long value;

  Data_Get_Struct(self, CAtomicFixnum, atomic);

#ifdef __USE_GCC_ATOMIC
  value = __atomic_load_n(&atomic->value, __ATOMIC_SEQ_CST);
#else
  pthread_mutex_lock(&atomic->mutex);
  value = atomic->value;
  pthread_mutex_unlock(&atomic->mutex);
#endif

  return INT2FIX(value);
}

VALUE method_atomic_fixnum_value_eq(VALUE self, VALUE value) {
  CAtomicFixnum* atomic;
  long new_value;

  Check_Type(value, T_FIXNUM);

  new_value = FIX2INT(value);
  Data_Get_Struct(self, CAtomicFixnum, atomic);

#ifdef __USE_GCC_ATOMIC
  __atomic_store_n(&atomic->value, new_value, __ATOMIC_SEQ_CST);
#else
  pthread_mutex_lock(&atomic->mutex);
  atomic->value = new_value;
  pthread_mutex_unlock(&atomic->mutex);
#endif

  return(value);
}

VALUE method_atomic_fixnum_increment(VALUE self) {
  CAtomicFixnum* atomic;
  long value;

  Data_Get_Struct(self, CAtomicFixnum, atomic);

#ifdef __USE_GCC_ATOMIC
  value = __atomic_add_fetch(&atomic->value, 1, __ATOMIC_SEQ_CST);
#else
  pthread_mutex_lock(&atomic->mutex);
  value = ++atomic->value;
  pthread_mutex_unlock(&atomic->mutex);

#endif
  return(INT2FIX(value));
}

VALUE method_atomic_fixnum_decrement(VALUE self) {
  CAtomicFixnum* atomic;
  long value;

  Data_Get_Struct(self, CAtomicFixnum, atomic);

#ifdef __USE_GCC_ATOMIC
  value = __atomic_sub_fetch(&atomic->value, 1, __ATOMIC_SEQ_CST);
#else
  pthread_mutex_lock(&atomic->mutex);
  value = --atomic->value;
  pthread_mutex_unlock(&atomic->mutex);
#endif

  return(INT2FIX(value));
}

VALUE method_atomic_fixnum_compare_and_set(VALUE self, VALUE rb_expect, VALUE rb_update) {
  CAtomicFixnum* atomic;
  long expect, update;

#ifdef __USE_GCC_ATOMIC
  VALUE value;
#else
  VALUE value = Qfalse;
#endif

  Check_Type(rb_expect, T_FIXNUM);
  Check_Type(rb_update, T_FIXNUM);

  Data_Get_Struct(self, CAtomicFixnum, atomic);

  expect = FIX2INT(rb_expect);
  update = FIX2INT(rb_update);

#ifdef __USE_GCC_ATOMIC
  value = __atomic_compare_exchange_n(&atomic->value, &expect, update, false,
      __ATOMIC_RELEASE, __ATOMIC_SEQ_CST) ? Qtrue : Qfalse;
#else
  pthread_mutex_lock(&atomic->mutex);
  if (atomic->value == expect) {
    atomic->value = update;
    value = Qtrue;
  }
  pthread_mutex_unlock(&atomic->mutex);
#endif

  return(value);
}
