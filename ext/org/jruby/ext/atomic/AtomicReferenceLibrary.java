// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
import org.jruby.util.unsafe.UnsafeFactory;
import org.jruby.util.unsafe.UnsafeGetter;

/**
 * This library adds an atomic reference type to JRuby for use in the atomic
 * library. We do a native version to avoid the implicit value coercion that
 * normally happens through JI.
 * 
 * @author headius
 */
public class AtomicReferenceLibrary implements Library {
    public void load(Ruby runtime, boolean wrap) throws IOException {
        RubyClass atomicCls = runtime.defineClass("Atomic", runtime.getObject(), JRUBYREFERENCE_ALLOCATOR);
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
                UNSAFE = UnsafeGetter.getUnsafe();
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

        @JRubyMethod(name = {"compare_and_set", "compare_and_swap"})
        public IRubyObject compare_and_set(ThreadContext context, IRubyObject oldValue, IRubyObject newValue) {
            return context.runtime.newBoolean(UNSAFE.compareAndSwapObject(this, referenceOffset, oldValue, newValue));
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
