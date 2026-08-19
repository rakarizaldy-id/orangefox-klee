#include "omapi_protocol.h"

#include <cassert>
#include <cstdint>

int main() {
    using namespace klee::omapi;

    assert(AidLengthAllowed(0));
    assert(!AidLengthAllowed(1));
    assert(!AidLengthAllowed(4));
    assert(AidLengthAllowed(5));
    assert(AidLengthAllowed(16));
    assert(!AidLengthAllowed(17));

    assert(P2Allowed(0x00));
    assert(P2Allowed(0x04));
    assert(P2Allowed(0x08));
    assert(P2Allowed(0x0c));
    assert(!P2Allowed(0x01));

    std::uint8_t cla = 0;
    assert(RouteClassByte(0x00, 0, &cla) && cla == 0x00);
    assert(RouteClassByte(0x00, 3, &cla) && cla == 0x03);
    assert(RouteClassByte(0x00, 4, &cla) && cla == 0x40);
    assert(RouteClassByte(0x00, 19, &cla) && cla == 0x4f);
    assert(!RouteClassByte(0x00, 20, &cla));

    // Secure-messaging indication is translated for channels 4..19.
    assert(RouteClassByte(0x0c, 4, &cla) && cla == 0x60);

    assert(SelectNextSucceeded(0x9000));
    assert(SelectNextSucceeded(0x6283));
    assert(SelectNextSucceeded(0x63c0));
    assert(SelectNextNotFound(0x6a82));
    assert(!SelectNextSucceeded(0x6a82));

    assert(RetryWithCorrectLe(0x6c, 5));
    assert(!RetryWithCorrectLe(0x6c, 4));
    assert(MoreResponseData(0x61));
    assert(!MoreResponseData(0x90));
    return 0;
}
