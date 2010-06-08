import java.io.IOException;
        
import org.jruby.Ruby;
import org.jruby.runtime.load.BasicLibraryService;

public class AtomicReferenceService implements BasicLibraryService {
    public boolean basicLoad(final Ruby runtime) throws IOException {
        new org.jruby.ext.atomic.AtomicReferenceLibrary().load(runtime, false);
        return true;
    }
}

