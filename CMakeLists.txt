cmake_minimum_required(VERSION 2.8.12...4.0.0)

project(mcpelauncher-webview)

option(USE_NATIVE_MACOS_WEBVIEW "Use native WKWebView on macOS instead of Qt WebEngine" OFF)

if(APPLE AND USE_NATIVE_MACOS_WEBVIEW)
    # Native macOS WKWebView implementation.
    # Uses the system Safari engine, which stays current with OS updates.
    # Avoids the need for Qt WebEngine (bundled Chromium) entirely.
    enable_language(OBJC)
    add_executable(mcpelauncher-webview src/main_macos.m)
    target_compile_options(mcpelauncher-webview PRIVATE -fobjc-arc)
    target_link_libraries(mcpelauncher-webview "-framework Cocoa" "-framework WebKit")
else()
    set(CMAKE_CXX_STANDARD 11)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_AUTOUIC ON)

    if(CMAKE_VERSION VERSION_LESS "3.7.0")
        set(CMAKE_INCLUDE_CURRENT_DIR ON)
    endif()

    find_package(Qt6 COMPONENTS Core Widgets WebEngineWidgets Qml REQUIRED)

    add_executable(mcpelauncher-webview src/main.cpp src/qml.qrc src/main.h)
    target_link_libraries(mcpelauncher-webview Qt6::Core Qt6::Widgets Qt6::WebEngineWidgets Qt6::Qml)

    if (QT_RPATH AND NOT QT_RPATH STREQUAL "")
        set_target_properties(mcpelauncher-webview PROPERTIES INSTALL_RPATH ${QT_RPATH})
    endif()
endif()

install(TARGETS mcpelauncher-webview RUNTIME COMPONENT webview DESTINATION bin)
