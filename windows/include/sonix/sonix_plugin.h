#ifndef FLUTTER_PLUGIN_SONIX_PLUGIN_H_
#define FLUTTER_PLUGIN_SONIX_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace sonix {

class SonixPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  SonixPlugin();
  virtual ~SonixPlugin();

  SonixPlugin(const SonixPlugin&) = delete;
  SonixPlugin& operator=(const SonixPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace sonix

// C-style function for Flutter plugin registration
extern "C" __declspec(dllexport) void SonixPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#endif  // FLUTTER_PLUGIN_SONIX_PLUGIN_H_