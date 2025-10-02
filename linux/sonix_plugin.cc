#include "include/sonix/sonix_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

namespace sonix {

// Static method to register the plugin
void SonixPlugin::RegisterWithRegistrar(FlPluginRegistrar* registrar) {
  // We don't need method channels since Sonix uses FFI directly
  // This plugin exists only to bundle libsonix_native.so
  SonixPlugin* plugin = new SonixPlugin();
  
  g_object_set_data_full(G_OBJECT(registrar), "plugin", plugin,
                         (GDestroyNotify) [](gpointer data) {
                           delete static_cast<SonixPlugin*>(data);
                         });
}

SonixPlugin::SonixPlugin() {}

SonixPlugin::~SonixPlugin() {}

void SonixPlugin::HandleMethodCall(FlMethodCall* method_call) {
  // No method calls needed - Sonix uses FFI directly
  fl_method_call_respond_not_implemented(method_call, nullptr);
}

}  // namespace sonix

// C-style function for Flutter plugin registration
extern "C" __attribute__((visibility("default"))) void sonix_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  sonix::SonixPlugin::RegisterWithRegistrar(registrar);
}