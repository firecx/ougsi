#include "configuration.h"

#include <iostream>
#include <string_view>

namespace {

constexpr std::string_view usage =
    "Запуск агента\n"
    "  node-agent --check-config <UUID узла> <URL HTTPS>\n"
    "  node-agent --help\n";

} // namespace

int main(int argc, char* argv[]) {
    if (argc == 2 && std::string_view(argv[1]) == "--help") {
        std::cout << usage;
        return 0;
    }
    if (argc != 4 || std::string_view(argv[1]) != "--check-config") {
        std::cerr << usage;
        return 2;
    }

    switch (ougsi::validateConfiguration(argv[2], argv[3])) {
    case ougsi::ConfigurationError::none:
        std::cout << "Конфигурация агента прошла проверку.\n";
        return 0;
    case ougsi::ConfigurationError::invalidNodeId:
        std::cerr << "Идентификатор узла должен быть UUID в нижнем регистре.\n";
        return 2;
    case ougsi::ConfigurationError::invalidManagementUrl:
        std::cerr << "Укажите адрес службы управления ВМ в формате https://узел[:порт][/].\n";
        return 2;
    }
    return 2;
}
