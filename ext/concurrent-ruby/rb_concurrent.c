#include <ruby.h>
/*#include <time.h>*/
#include <pthread.h>
/*#include <stdio.h>*/

// module definition
static VALUE rb_mConcurrent;

void Init_concurrent() {

  rb_mConcurrent = rb_define_module("Concurrent");
}
