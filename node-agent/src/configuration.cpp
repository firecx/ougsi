#include "configuration.h"

#include <algorithm>
#include <charconv>

namespace ougsi {
namespace {

bool isDecimalDigit(char character) {
    return character >= '0' && character <= '9';
}

bool validNodeId(std::string_view nodeId) {
    if (nodeId.size() != 36) {
        return false;
    }
    for (std::size_t index = 0; index < nodeId.size(); ++index) {
        const char character = nodeId[index];
        if (index == 8 || index == 13 || index == 18 || index == 23) {
            if (character != '-') {
                return false;
            }
        } else if (!isDecimalDigit(character) && !(character >= 'a' && character <= 'f')) {
            return false;
        }
    }
    return true;
}

bool validDnsLabel(std::string_view label) {
    if (label.empty() || label.size() > 63 || label.front() == '-' || label.back() == '-') {
        return false;
    }
    return std::all_of(label.begin(), label.end(), [](char character) {
        return isDecimalDigit(character) || (character >= 'a' && character <= 'z') ||
               (character >= 'A' && character <= 'Z') || character == '-';
    });
}

bool decimalInRange(std::string_view text, unsigned minimum, unsigned maximum) {
    if (text.empty()) {
        return false;
    }
    unsigned value = 0;
    const auto end = text.data() + text.size();
    const auto result = std::from_chars(text.data(), end, value);
    return result.ec == std::errc{} && result.ptr == end && value >= minimum && value <= maximum;
}

bool validHost(std::string_view host) {
    if (host.empty() || host.size() > 253 || host.back() == '.') {
        return false;
    }
    const bool dottedDecimal =
        host.find('.') != std::string_view::npos &&
        std::all_of(host.begin(), host.end(), [](char character) {
            return isDecimalDigit(character) || character == '.';
        });
    int labelCount = 0;
    while (!host.empty()) {
        const auto separator = host.find('.');
        const auto label = host.substr(0, separator);
        if (!validDnsLabel(label) || (dottedDecimal && !decimalInRange(label, 0, 255))) {
            return false;
        }
        ++labelCount;
        if (separator == std::string_view::npos) {
            break;
        }
        host.remove_prefix(separator + 1);
    }
    return !dottedDecimal || labelCount == 4;
}

bool validManagementUrl(std::string_view url) {
    constexpr std::string_view scheme = "https://";
    if (url.substr(0, scheme.size()) != scheme) {
        return false;
    }
    auto authority = url.substr(scheme.size());
    if (!authority.empty() && authority.back() == '/') {
        authority.remove_suffix(1);
    }
    const auto separator = authority.find(':');
    if (separator != std::string_view::npos &&
        !decimalInRange(authority.substr(separator + 1), 1, 65535)) {
        return false;
    }
    return validHost(authority.substr(0, separator));
}

} // namespace

ConfigurationError validateConfiguration(std::string_view nodeId, std::string_view managementUrl) {
    if (!validNodeId(nodeId)) {
        return ConfigurationError::invalidNodeId;
    }
    if (!validManagementUrl(managementUrl)) {
        return ConfigurationError::invalidManagementUrl;
    }
    return ConfigurationError::none;
}

} // namespace ougsi
