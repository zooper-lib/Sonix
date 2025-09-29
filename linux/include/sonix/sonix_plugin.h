#ifndef FLUTTER_PLUGIN_SONIX_PLUGIN_H_
#define FLUTTER_PLUGIN_SONIX_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

namespace sonix {

class SonixPlugin {
 public:
  static void RegisterWithRegistrar(FlPluginRegistrar* registrar);

  SonixPlugin();
  virtual ~SonixPlugin();

  SonixPlugin(const SonixPlugin&) = delete;
  SonixPlugin& operator=(const SonixPlugin&) = delete;

 private:
  void HandleMethodCall(FlMethodCall* method_call);
};

}  // namespace sonix

// C-style function for Flutter plugin registration
extern "C" __attribute__((visibility("default"))) void sonix_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

#endif  // FLUTTER_PLUGIN_SONIX_PLUGIN_H_