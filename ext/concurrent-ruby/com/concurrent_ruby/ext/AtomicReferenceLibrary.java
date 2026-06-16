package com.concurrent_ruby.ext;

import static org.jruby.runtime.Visibility.PRIVATE;

import java.lang.reflect.Field;
import java.io.IOException;
import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.Library;

/**
 * This library adds an atomic reference type to JRuby for use in the atomic
 * library. We do a native version to avoid the implicit value coercion that
 * normally happens through JI.
 * 
 * @author headius
 */
public class AtomicReferenceLibrary implements Library {
    public void load(Ruby runtime, boolean wrap) throws IOException {
        RubyModule concurrentMod = runtime.defineModule("Concurrent");
        RubyClass atomicCls = concurrentMod.defineClassUnder("JavaAtomicReference", runtime.getObject(), JRUBYREFERENCE_ALLOCATOR);
        try {
            sun.misc.Unsafe.class.getMethod("getAndSetObject", Object.class);
            atomicCls.setAllocator(JRUBYREFERENCE8_ALLOCATOR);
        } catch (Exception e) {
            // leave it as Java 6/7 version
        }
        atomicCls.defineAnnotatedMethods(JRubyReference.class);
    }
    
    private static final ObjectAllocator JRUBYREFERENCE_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klazz) {
            return new JRubyReference(runtime, klazz);
        }
    };
    
    private static final ObjectAllocator JRUBYREFERENCE8_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klazz) {
            return new JRubyReference8(runtime, klazz);
        }
    };

    @JRubyClass(name="JRubyReference", parent="Object")
    public static class JRubyReference extends RubyObject {
        volatile IRubyObject reference;
        
        static final sun.misc.Unsafe UNSAFE;
        static final long referenceOffset;

        static {
            try {
                UNSAFE = UnsafeHolder.U;
                Class k = JRubyReference.class;
                referenceOffset = UNSAFE.objectFieldOffset(k.getDeclaredField("reference"));
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }

        public JRubyReference(Ruby runtime, RubyClass klass) {
            super(runtime, klass);
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context) {
            UNSAFE.putObject(this, referenceOffset, context.nil);
            return context.nil;
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context, IRubyObject value) {
            UNSAFE.putObject(this, referenceOffset, value);
            return context.nil;
        }

        @JRubyMethod(name = {"get", "value"})
        public IRubyObject get() {
            return reference;
        }

        @JRubyMethod(name = {"set", "value="})
        public IRubyObject set(IRubyObject newValue) {
            UNSAFE.putObjectVolatile(this, referenceOffset, newValue);
            return newValue;
        }

        @JRubyMethod(name = "_compare_and_set", visibility = PRIVATE)
        public IRubyObject compare_and_set(ThreadContext context, IRubyObject expectedValue, IRubyObject newValue) {
            Ruby runtime = context.runtime;
            return runtime.newBoolean(UNSAFE.compareAndSwapObject(this, referenceOffset, expectedValue, newValue));
        }

        @JRubyMethod(name = {"get_and_set", "swap"})
        public IRubyObject get_and_set(ThreadContext context, IRubyObject newValue) {
            // less-efficient version for Java 6 and 7
            while (true) {
                IRubyObject oldValue = get();
                if (UNSAFE.compareAndSwapObject(this, referenceOffset, oldValue, newValue)) {
                    return oldValue;
                }
            }
        }
    }

    private static final class UnsafeHolder {
	private UnsafeHolder(){}
	    
	public static final sun.misc.Unsafe U = loadUnsafe();
	
	private static sun.misc.Unsafe loadUnsafe() {
	    try {
		Class unsafeClass = Class.forName("sun.misc.Unsafe");
		Field f = unsafeClass.getDeclaredField("theUnsafe");
		f.setAccessible(true);
		return (sun.misc.Unsafe) f.get(null);
	    } catch (Exception e) {
		return null;
	    }
	}
    }
    
    public static class JRubyReference8 extends JRubyReference {
        public JRubyReference8(Ruby runtime, RubyClass klass) {
            super(runtime, klass);
        }

        @Override
        public IRubyObject get_and_set(ThreadContext context, IRubyObject newValue) {
            // efficient version for Java 8
            return (IRubyObject)UNSAFE.getAndSetObject(this, referenceOffset, newValue);
        }
    }
}
