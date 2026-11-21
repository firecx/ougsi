#include "configuration.h"

#include <iostream>
#include <string_view>

int main() {
    using ougsi::ConfigurationError;
    using ougsi::validateConfiguration;

    constexpr std::string_view nodeId = "14c48a31-e5a4-491b-8f96-6a82876afa95";
    constexpr std::string_view managementUrl = "https://vm.internal:8443/";
    const struct {
        std::string_view nodeId;
        std::string_view managementUrl;
        ConfigurationError expected;
    } cases[] = {
        {nodeId, managementUrl, ConfigurationError::none},
        {nodeId, "https://vm-service", ConfigurationError::none},
        {nodeId, "https://127.0.0.1:65535", ConfigurationError::none},
        {nodeId, "https://VM.example:1", ConfigurationError::none},
        {"", managementUrl, ConfigurationError::invalidNodeId},
        {"14C48A31-e5a4-491b-8f96-6a82876afa95", managementUrl, ConfigurationError::invalidNodeId},
        {"14c48g31-e5a4-491b-8f96-6a82876afa95", managementUrl, ConfigurationError::invalidNodeId},
        {"14c48a31_e5a4-491b-8f96-6a82876afa95", managementUrl, ConfigurationError::invalidNodeId},
        {nodeId, "http://vm.internal", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm.internal/api", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm.internal?mode=1", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm.internal#fragment", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://user@vm.internal", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm..internal", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://-vm.internal", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://999.0.0.1", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://127.1", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm.internal:", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm.internal:0", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm.internal:65536", ConfigurationError::invalidManagementUrl},
        {nodeId, "https://vm.internal:8443a", ConfigurationError::invalidManagementUrl},
    };

    bool success = true;
    for (const auto& test : cases) {
        if (validateConfiguration(test.nodeId, test.managementUrl) != test.expected) {
            std::cerr << "Unexpected validation result for [" << test.nodeId << "] ["
                      << test.managementUrl << "]\n";
            success = false;
        }
    }
    return success ? 0 : 1;
}
