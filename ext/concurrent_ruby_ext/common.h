#ifndef rb_check_arity

// https://github.com/ruby/ruby/blob/ruby_2_0_0/include/ruby/intern.h
// rb_check_arity was added in Ruby 2.0

#define rb_check_arity(argc, min, max) do { \
  if (((argc) < (min)) || ((argc) > (max) && (max) != UNLIMITED_ARGUMENTS)) \
  rb_error_arity(argc, min, max); \
} while(0)

#endif
