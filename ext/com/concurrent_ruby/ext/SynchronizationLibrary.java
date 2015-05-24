package com.concurrent_ruby.ext;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicBoolean;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.Library;
import org.jruby.runtime.Block;
import org.jruby.runtime.Visibility;
import org.jruby.RubyBoolean;
import org.jruby.RubyNil;
import org.jruby.runtime.ThreadContext;
import org.jruby.util.unsafe.UnsafeHolder;

public class SynchronizationLibrary implements Library {

    public void load(Ruby runtime, boolean wrap) throws IOException {
        RubyModule synchronizationModule = runtime.
                defineModule("Concurrent").
                defineModuleUnder("Synchronization");
        RubyClass parentClass = synchronizationModule.getClass("AbstractObject");

        if (parentClass == null)
            throw runtime.newRuntimeError("Concurrent::Synchronization::AbstractObject is missing");

        RubyClass synchronizedObjectJavaClass =
                synchronizationModule.defineClassUnder("JavaObject", parentClass, JRUBYREFERENCE_ALLOCATOR);

        synchronizedObjectJavaClass.defineAnnotatedMethods(JavaObject.class);
    }

    private static final ObjectAllocator JRUBYREFERENCE_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klazz) {
            return new JavaObject(runtime, klazz);
        }
    };

    @JRubyClass(name = "JavaObject", parent = "AbstractObject")
    public static class JavaObject extends RubyObject {

        public JavaObject(Ruby runtime, RubyClass metaClass) {
            super(runtime, metaClass);
        }

        @JRubyMethod
        public IRubyObject initialize(ThreadContext context) {
            return this;
        }

        @JRubyMethod(name = "synchronize", visibility = Visibility.PROTECTED)
        public IRubyObject rubySynchronize(ThreadContext context, Block block) {
            synchronized (this) {
                return block.yield(context, null);
            }
        }

        @JRubyMethod(name = "ns_wait", optional = 1, visibility = Visibility.PROTECTED)
        public IRubyObject nsWait(ThreadContext context, IRubyObject[] args) {
            Ruby runtime = context.runtime;
            if (args.length > 1) {
                throw runtime.newArgumentError(args.length, 1);
            }
            Double timeout = null;
            if (args.length > 0 && !args[0].isNil()) {
                timeout = args[0].convertToFloat().getDoubleValue();
                if (timeout < 0) {
                    throw runtime.newArgumentError("time interval must be positive");
                }
            }
            if (Thread.interrupted()) {
                throw runtime.newConcurrencyError("thread interrupted");
            }
            boolean success = false;
            try {
                success = context.getThread().wait_timeout(this, timeout);
            } catch (InterruptedException ie) {
                throw runtime.newConcurrencyError(ie.getLocalizedMessage());
            } finally {
                // An interrupt or timeout may have caused us to miss
                // a notify that we consumed, so do another notify in
                // case someone else is available to pick it up.
                if (!success) {
                    this.notify();
                }
            }
            return this;
        }

        @JRubyMethod(name = "ns_signal", visibility = Visibility.PROTECTED)
        public IRubyObject nsSignal(ThreadContext context) {
            notify();
            return this;
        }

        @JRubyMethod(name = "ns_broadcast", visibility = Visibility.PROTECTED)
        public IRubyObject nsBroadcast(ThreadContext context) {
            notifyAll();
            return this;
        }

        @JRubyMethod(name = "ensure_ivar_visibility!", visibility = Visibility.PROTECTED)
        public IRubyObject ensureIvarVisibilityBang(ThreadContext context) {
            if (UnsafeHolder.SUPPORTS_FENCES)
                UnsafeHolder.storeFence();
            else
                anVolatileField = 1;
            return context.nil;
        }

        private volatile int anVolatileField = 0; // TODO unused on JAVA8
        public static final long AN_VOLATILE_FIELD_OFFSET =
                UnsafeHolder.fieldOffset(JavaObject.class, "anVolatileField");

        @JRubyMethod(name = "instance_variable_get_volatile", visibility = Visibility.PROTECTED)
        public IRubyObject instanceVariableGetVolatile(ThreadContext context, IRubyObject name) {
            if (UnsafeHolder.U == null) {
                synchronized (this) {
                    return instance_variable_get(context, name);
                }
            } else if (UnsafeHolder.SUPPORTS_FENCES) {
                UnsafeHolder.loadFence();
                return instance_variable_get(context, name);
            } else {
                UnsafeHolder.U.getIntVolatile(this, AN_VOLATILE_FIELD_OFFSET);
                return instance_variable_get(context, name);
            }
        }

        @JRubyMethod(name = "instance_variable_set_volatile", visibility = Visibility.PROTECTED)
        public IRubyObject InstanceVariableSetVolatile(ThreadContext context, IRubyObject name, IRubyObject value) {
            if (UnsafeHolder.U == null) {
                synchronized (this) {
                    return instance_variable_set(name, value);
                }
            } else if (UnsafeHolder.SUPPORTS_FENCES) {
                IRubyObject result = instance_variable_set(name, value);
                UnsafeHolder.storeFence();
                return result;
            } else {
                UnsafeHolder.U.putIntVolatile(this, AN_VOLATILE_FIELD_OFFSET, 1);
                IRubyObject result = instance_variable_set(name, value);
                return result;
            }
        }
    }
}
