//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <sonix/sonix_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) sonix_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SonixPlugin");
  sonix_plugin_register_with_registrar(sonix_registrar);
}
