#include "include/sonix/sonix_plugin.h"

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace sonix {

// Static method to register the plugin
void SonixPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  // We don't need method channels since Sonix uses FFI directly
  // This plugin exists only to bundle sonix_native.dll
  auto plugin = std::make_unique<SonixPlugin>();
  registrar->AddPlugin(std::move(plugin));
}

SonixPlugin::SonixPlugin() {}

SonixPlugin::~SonixPlugin() {}

void SonixPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // No method calls needed - Sonix uses FFI directly
  result->NotImplemented();
}

}  // namespace sonix

// C-style function that Flutter expects for plugin registration
extern "C" __declspec(dllexport) void SonixPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  sonix::SonixPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}