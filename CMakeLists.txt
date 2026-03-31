cmake_minimum_required(VERSION 2.8.12...4.0.0)

project(mcpelauncher-webview)

# On macOS, use native WKWebView (Safari engine) instead of Qt WebEngine.
# Qt WebEngine bundles Chrome 75 which can't negotiate TLS with modern
# Microsoft Xbox Live servers. WKWebView uses the system Safari engine
# (always current) and supports all modern auth flows including passkeys.
# Same binary interface: mcpelauncher-webview <startUrl> <endUrl> → stdout
if(APPLE)
    option(USE_NATIVE_MACOS_WEBVIEW "Use native WKWebView instead of Qt WebEngine" ON)
    if(USE_NATIVE_MACOS_WEBVIEW)
        enable_language(OBJC)
        add_executable(mcpelauncher-webview src/main_macos.m)
        target_compile_options(mcpelauncher-webview PRIVATE -fobjc-arc)
        target_link_libraries(mcpelauncher-webview "-framework Cocoa" "-framework WebKit")
        install(TARGETS mcpelauncher-webview RUNTIME COMPONENT webview DESTINATION bin)
        return()
    endif()
endif()

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

install(TARGETS mcpelauncher-webview RUNTIME COMPONENT webview DESTINATION bin)
