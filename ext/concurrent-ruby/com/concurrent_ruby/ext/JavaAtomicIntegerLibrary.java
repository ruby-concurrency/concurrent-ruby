package com.concurrent_ruby.ext;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicLong;
import org.jruby.Ruby;
import org.jruby.RubyBignum;
import org.jruby.RubyClass;
import org.jruby.RubyFixnum;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.Library;
import org.jruby.runtime.Block;

public class JavaAtomicIntegerLibrary implements Library {

    public void load(Ruby runtime, boolean wrap) throws IOException {
        RubyModule concurrentMod = runtime.defineModule("Concurrent");
        RubyClass atomicCls = concurrentMod.defineClassUnder("JavaAtomicInteger", runtime.getObject(), JRUBYREFERENCE_ALLOCATOR);

        atomicCls.defineAnnotatedMethods(JavaAtomicInteger.class);
    }

    private static final ObjectAllocator JRUBYREFERENCE_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klazz) {
            return new JavaAtomicInteger(runtime, klazz);
        }
    };

    @JRubyClass(name = "JavaAtomicInteger", parent = "Object")
    public static class JavaAtomicInteger extends RubyObject {

        private AtomicLong atomicLong;

        public JavaAtomicInteger(Ruby runtime, RubyClass metaClass) {
            super(runtime, metaClass);
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context) {
            this.atomicLong = new AtomicLong(0);
            return context.nil;
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context, IRubyObject value) {
            this.atomicLong = new AtomicLong(rubyIntegerToLong(value));
            return context.nil;
        }

        @JRubyMethod(name = "value")
        public IRubyObject getValue() {
            return RubyBignum.newBignum(getRuntime(), atomicLong.get());
        }

        @JRubyMethod(name = "value=")
        public IRubyObject setValue(ThreadContext context, IRubyObject newValue) {
            atomicLong.set(rubyIntegerToLong(newValue));
            return context.nil;
        }

        @JRubyMethod(name = {"increment", "up"})
        public IRubyObject increment() {
            return RubyBignum.newBignum(getRuntime(), atomicLong.incrementAndGet());
        }

        @JRubyMethod(name = {"increment", "up"})
        public IRubyObject increment(IRubyObject value) {
            long delta = rubyIntegerToLong(value);
            return RubyBignum.newBignum(getRuntime(), atomicLong.addAndGet(delta));
        }

        @JRubyMethod(name = {"decrement", "down"})
        public IRubyObject decrement() {
            return RubyBignum.newBignum(getRuntime(), atomicLong.decrementAndGet());
        }

        @JRubyMethod(name = {"decrement", "down"})
        public IRubyObject decrement(IRubyObject value) {
            long delta = rubyIntegerToLong(value);
            return RubyBignum.newBignum(getRuntime(), atomicLong.addAndGet(-delta));
        }

        @JRubyMethod(name = "compare_and_set")
        public IRubyObject compareAndSet(ThreadContext context, IRubyObject expect, IRubyObject update) {
            return getRuntime().newBoolean(atomicLong.compareAndSet(rubyIntegerToLong(expect), rubyIntegerToLong(update)));
        }

        @JRubyMethod
        public IRubyObject update(ThreadContext context, Block block) {
            for (;;) {
                long _oldValue       = atomicLong.get();
                IRubyObject oldValue = RubyBignum.newBignum(getRuntime(), _oldValue);
                IRubyObject newValue = block.yield(context, oldValue);
                if (atomicLong.compareAndSet(_oldValue, rubyIntegerToLong(newValue))) {
                    return newValue;
                }
            }
        }

        private long rubyIntegerToLong(IRubyObject value) {
            if (value instanceof RubyBignum) {
                RubyBignum bigNum = (RubyBignum) value;
                return bigNum.getLongValue();
            } else if (value instanceof RubyFixnum) {
                RubyFixnum fixNum = (RubyFixnum) value;
                return fixNum.getLongValue();
            } else {
                throw getRuntime().newArgumentError("value must be an Integer");
            }
        }
    }
}
