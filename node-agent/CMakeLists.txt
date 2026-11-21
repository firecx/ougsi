cmake_minimum_required(VERSION 3.16)
project(ougsi_node_agent LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(agent_configuration STATIC src/configuration.cpp)
target_include_directories(agent_configuration PUBLIC src)

add_executable(node-agent src/main.cpp)
target_link_libraries(node-agent PRIVATE agent_configuration)

if(MSVC)
    target_compile_options(node-agent PRIVATE /utf-8)
endif()

include(CTest)
if(BUILD_TESTING)
    add_executable(agent_configuration_test tests/configuration_test.cpp)
    target_link_libraries(agent_configuration_test PRIVATE agent_configuration)
    add_test(NAME agent_configuration_validation COMMAND agent_configuration_test)
    add_test(NAME node_agent_help COMMAND node-agent --help)
    add_test(NAME node_agent_checks_configuration
        COMMAND node-agent --check-config 14c48a31-e5a4-491b-8f96-6a82876afa95 https://localhost:8443)
    add_test(NAME node_agent_rejects_http
        COMMAND node-agent --check-config 14c48a31-e5a4-491b-8f96-6a82876afa95 http://localhost:8443)
    set_tests_properties(node_agent_rejects_http PROPERTIES WILL_FAIL TRUE)
endif()
