#pragma once

#include <cstddef>
#include <cstdint>

namespace klee::omapi {

inline constexpr bool AidLengthAllowed(std::size_t length) {
    return length == 0 || (length >= 5 && length <= 16);
}

inline constexpr bool P2Allowed(std::uint8_t p2) {
    return p2 == 0x00 || p2 == 0x04 || p2 == 0x08 || p2 == 0x0c;
}

// Encode an ISO/IEC 7816 logical channel in the APDU class byte.
// Returns false for channels outside the OMAPI-defined 0..19 range.
inline constexpr bool RouteClassByte(std::uint8_t original, std::uint8_t channel,
                                     std::uint8_t* routed) {
    if (routed == nullptr)
        return false;

    if (channel < 4) {
        *routed = static_cast<std::uint8_t>((original & 0xbcU) | channel);
        return true;
    }

    if (channel < 20) {
        const bool secure_messaging =
                ((original & 0x40U) == 0U) && ((original & 0x0cU) != 0U);
        std::uint8_t value = static_cast<std::uint8_t>(
                (original & 0xb0U) | 0x40U | (channel - 4U));
        if (secure_messaging)
            value = static_cast<std::uint8_t>(value | 0x20U);
        *routed = value;
        return true;
    }

    return false;
}

inline constexpr bool SelectNextSucceeded(std::uint16_t sw) {
    return (sw & 0xf000U) == 0x9000U ||
           (sw & 0xff00U) == 0x6200U ||
           (sw & 0xff00U) == 0x6300U;
}

inline constexpr bool SelectNextNotFound(std::uint16_t sw) {
    return (sw & 0xff00U) == 0x6a00U;
}

inline constexpr bool RetryWithCorrectLe(std::uint8_t sw1, std::size_t command_length) {
    return sw1 == 0x6cU && command_length >= 5U;
}

inline constexpr bool MoreResponseData(std::uint8_t sw1) {
    return sw1 == 0x61U;
}

}  // namespace klee::omapi
