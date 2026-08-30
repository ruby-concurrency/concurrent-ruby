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
size_t cr_atomic_memsize(const void *ptr);
#ifdef CR_GC_COMPACTION
void cr_atomic_compact(void *ptr);
#define CR_ATOMIC_DCOMPACT_INIT .dcompact = cr_atomic_compact,
#else
#define CR_ATOMIC_DCOMPACT_INIT
#endif

#define CR_DEFINE_ATOMIC_DATA_TYPE(var, name)             \
  static const rb_data_type_t var = {                     \
    .wrap_struct_name = (name),                           \
    .function = {                                         \
      .dmark = cr_atomic_mark,                            \
      .dfree = RUBY_TYPED_DEFAULT_FREE,                   \
      .dsize = cr_atomic_memsize,                         \
      CR_ATOMIC_DCOMPACT_INIT                             \
    },                                                    \
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED, \
  }

/* Each primitive prefers ruby/atomic.h's helper when defined and falls back
 * to GCC/Clang __atomic_* builtins. Not every macro is available on every
 * supported Ruby: RUBY_ATOMIC_PTR_LOAD landed in 3.3, RUBY_ATOMIC_VALUE_SET
 * in 4.0; the others are present from 3.0. */

static inline VALUE cr_atomic_value_load(cr_atomic_t *atomic) {
#if defined(RUBY_ATOMIC_PTR_LOAD)
  return (VALUE)RUBY_ATOMIC_PTR_LOAD(atomic->value);
#elif defined(__GNUC__) || defined(__clang__)
  return __atomic_load_n(&atomic->value, __ATOMIC_SEQ_CST);
#else
#error "concurrent-ruby-ext requires RUBY_ATOMIC_PTR_LOAD or GCC/Clang atomic builtins"
#endif
}

/* The mutating helpers below do not announce a write barrier; callers must
 * follow each successful store with RB_OBJ_WRITTEN(self, oldv, newv) so the
 * WB_PROTECTED contract is honored. */

static inline void cr_atomic_value_set(cr_atomic_t *atomic, VALUE val) {
#if defined(RUBY_ATOMIC_VALUE_SET)
  RUBY_ATOMIC_VALUE_SET(atomic->value, val);
#elif defined(__GNUC__) || defined(__clang__)
  __atomic_store_n(&atomic->value, val, __ATOMIC_SEQ_CST);
#else
#error "concurrent-ruby-ext requires RUBY_ATOMIC_VALUE_SET or GCC/Clang atomic builtins"
#endif
}

/* Returns the previous slot value; the swap succeeded iff it equals oldval. */
static inline VALUE cr_atomic_value_cas(cr_atomic_t *atomic, VALUE oldval, VALUE newval) {
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

static inline VALUE cr_atomic_value_exchange(cr_atomic_t *atomic, VALUE val) {
#if defined(RUBY_ATOMIC_VALUE_EXCHANGE)
  return RUBY_ATOMIC_VALUE_EXCHANGE(atomic->value, val);
#elif defined(__GNUC__) || defined(__clang__)
  return __atomic_exchange_n(&atomic->value, val, __ATOMIC_SEQ_CST);
#else
#error "concurrent-ruby-ext requires RUBY_ATOMIC_VALUE_EXCHANGE or GCC/Clang atomic builtins"
#endif
}

VALUE ir_alloc(VALUE klass);
VALUE ir_initialize(int argc, VALUE *argv, VALUE self);
VALUE ir_get(VALUE self);
VALUE ir_set(VALUE self, VALUE new_value);
VALUE ir_get_and_set(VALUE self, VALUE new_value);
VALUE ir_compare_and_set(VALUE self, VALUE expect_value, VALUE new_value);

#endif
