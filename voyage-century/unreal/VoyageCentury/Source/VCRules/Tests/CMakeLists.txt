# Eigenständiger Test der Kampf-, Fähigkeits-, Status- und Segelregeln ohne Unreal Engine.
# Flags wie in Unreal: keine Exceptions, kein RTTI, Warnungen als Fehler.
cmake_minimum_required(VERSION 3.20)
project(VCRulesTests CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(vc_rules_tests
    TestMain.cpp
    CombatRulesTests.cpp
    AbilityRulesTests.cpp
    ShipRulesTests.cpp
    NavalCombatRulesTests.cpp
    NavalAbilityRulesTests.cpp
    ../Private/VCCombatRules.cpp
    ../Private/VCAbilityRules.cpp
    ../Private/VCShipRules.cpp
    ../Private/VCNavalCombatRules.cpp
    ../Private/VCNavalAbilityRules.cpp)
target_include_directories(vc_rules_tests PRIVATE ../Public)
target_compile_options(vc_rules_tests PRIVATE -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Werror -fno-exceptions -fno-rtti)

enable_testing()
add_test(NAME vc_rules_tests COMMAND vc_rules_tests)
