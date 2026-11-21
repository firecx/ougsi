#pragma once

#include <string_view>

namespace ougsi {

enum class ConfigurationError {
    none,
    invalidNodeId,
    invalidManagementUrl,
};

ConfigurationError validateConfiguration(std::string_view nodeId, std::string_view managementUrl);

} // namespace ougsi
