package org.jruby.ext.atomic;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicReferenceFieldUpdater;
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
        RubyModule atomicCls = runtime.getClass("Atomic");
        RubyClass jrubyRefClass = runtime.defineClassUnder("InternalReference", runtime.getObject(), JRUBYREFERENCE_ALLOCATOR, atomicCls);
        jrubyRefClass.setAllocator(JRUBYREFERENCE_ALLOCATOR);
        jrubyRefClass.defineAnnotatedMethods(JRubyReference.class);
    }
    
    private static final ObjectAllocator JRUBYREFERENCE_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klazz) {
            return new JRubyReference(runtime, klazz);
        }
    };

    @JRubyClass(name="JRubyReference", parent="Object")
    public static class JRubyReference extends RubyObject {
        private volatile IRubyObject reference;
        private final static AtomicReferenceFieldUpdater<JRubyReference, IRubyObject> UPDATER =
            AtomicReferenceFieldUpdater.newUpdater(JRubyReference.class, IRubyObject.class, "reference");

        public JRubyReference(Ruby runtime, RubyClass klass) {
            super(runtime, klass);
            reference = runtime.getNil();
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context) {
            Ruby runtime = context.getRuntime();
            UPDATER.set(this, runtime.getNil());
            return runtime.getNil();
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context, IRubyObject value) {
            Ruby runtime = context.getRuntime();
            UPDATER.set(this, value);
            return runtime.getNil();
        }

        @JRubyMethod(name = {"get", "value"})
        public IRubyObject get() {
            return UPDATER.get(this);
        }

        @JRubyMethod(name = {"set", "value="})
        public IRubyObject set(IRubyObject newValue) {
            UPDATER.set(this, newValue);
            return newValue;
        }

        @JRubyMethod
        public IRubyObject compare_and_set(ThreadContext context, IRubyObject oldValue, IRubyObject newValue) {
            return context.getRuntime().newBoolean(UPDATER.compareAndSet(this, oldValue, newValue));
        }

        @JRubyMethod
        public IRubyObject get_and_set(ThreadContext context, IRubyObject newValue) {
            return UPDATER.getAndSet(this, newValue);
        }
    }
}
