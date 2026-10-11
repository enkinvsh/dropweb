//go:build ios

#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <Security/Security.h>

typedef CFArrayRef (*copy_chain_fn)(SecTrustRef);

// Local definition wins at link time. On iOS 15+ forward to Security's own
// implementation; on 13–14 build the chain from the pre-15 API.
CFArrayRef SecTrustCopyCertificateChain(SecTrustRef trust) {
    static copy_chain_fn real;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *security = dlopen(
            "/System/Library/Frameworks/Security.framework/Security",
            RTLD_LAZY | RTLD_NOLOAD);
        if (security) {
            real = (copy_chain_fn)dlsym(security, "SecTrustCopyCertificateChain");
        }
    });
    if (real) {
        return real(trust);
    }
    CFIndex count = SecTrustGetCertificateCount(trust);
    CFMutableArrayRef chain =
        CFArrayCreateMutable(kCFAllocatorDefault, count, &kCFTypeArrayCallBacks);
    for (CFIndex i = 0; i < count; i++) {
        CFArrayAppendValue(chain, SecTrustGetCertificateAtIndex(trust, i));
    }
    return chain;
}
