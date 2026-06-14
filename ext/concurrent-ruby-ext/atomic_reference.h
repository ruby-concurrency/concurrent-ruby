#ifndef CONCURRENT_RUBY_ATOMIC_REFERENCE_H
#define CONCURRENT_RUBY_ATOMIC_REFERENCE_H 1

#include <ruby.h>
#include <ruby/version.h>

#ifdef HAVE_RUBY_ATOMIC_H
#include <ruby/atomic.h>
#endif

#if RUBY_API_VERSION_CODE >= 20700
#define CR_GC_COMPACTION 1
#endif

/* Storage shared by CAtomicReference, CAtomicBoolean, and CAtomicFixnum. */
typedef struct {
  VALUE value;
} cr_atomic_t;

void cr_atomic_mark(void *ptr);
void cr_atomic_free(void *ptr);
size_t cr_atomic_memsize(const void *ptr);
#ifdef CR_GC_COMPACTION
void cr_atomic_compact(void *ptr);
#endif

VALUE cr_atomic_value_load(const cr_atomic_t *atomic);
/* Returns the previous slot value; the CAS succeeded iff it equals oldval.
 * Does not announce a write barrier; callers must RB_OBJ_WRITTEN on success. */
VALUE cr_atomic_value_cas(cr_atomic_t *atomic, VALUE oldval, VALUE newval);

VALUE ir_alloc(VALUE klass);
VALUE ir_initialize(int argc, VALUE *argv, VALUE self);
VALUE ir_get(VALUE self);
VALUE ir_set(VALUE self, VALUE new_value);
VALUE ir_get_and_set(VALUE self, VALUE new_value);
VALUE ir_compare_and_set(VALUE self, VALUE expect_value, VALUE new_value);

#endif
