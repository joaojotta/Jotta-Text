/* Native Linux file dialogs through the desktop portal (GTK/KDE, including Flatpak). */
#include <gio/gio.h>
#include <stdio.h>
#include <string.h>

typedef struct { GMainLoop *loop; gchar *request; int status; } Dialog;

static void response(GDBusConnection *bus, const gchar *sender, const gchar *path,
                     const gchar *interface, const gchar *signal, GVariant *parameters,
                     gpointer data) {
  (void)bus; (void)sender; (void)interface; (void)signal;
  Dialog *dialog = data;
  if (!dialog->request || strcmp(path, dialog->request)) return;
  guint result;
  GVariant *values;
  g_variant_get(parameters, "(u@a{sv})", &result, &values);
  dialog->status = result == 1 ? 2 : 1;
  if (result == 0) {
    GVariant *uris = g_variant_lookup_value(values, "uris", G_VARIANT_TYPE("as"));
    if (uris && g_variant_n_children(uris) > 0) {
      const gchar *uri;
      g_variant_get_child(uris, 0, "&s", &uri);
      GError *error = NULL;
      gchar *filename = g_filename_from_uri(uri, NULL, &error);
      if (filename) {
        fwrite(filename, 1, strlen(filename), stdout);
        dialog->status = ferror(stdout) ? 1 : 0;
        g_free(filename);
      } else {
        fprintf(stderr, "Cannot open selection: %s\n", error->message);
        g_error_free(error);
      }
    }
    if (uris) g_variant_unref(uris);
  }
  g_variant_unref(values);
  g_main_loop_quit(dialog->loop);
}

int main(int argc, char **argv) {
  if (argc == 3 && (!strcmp(argv[1], "uri") || !strcmp(argv[1],"github-uri"))) {
    GError *error = NULL;
    if (!g_str_has_prefix(argv[2], !strcmp(argv[1],"github-uri")?"https://github.com/":"http://127.0.0.1:")) return 1;
    if (g_app_info_launch_default_for_uri(argv[2], NULL, &error)) return 0;
    fprintf(stderr, "Cannot open browser: %s\n", error->message);
    g_error_free(error);
    return 1;
  }
  if (argc < 2 || (strcmp(argv[1], "file") && strcmp(argv[1], "folder") && strcmp(argv[1], "save"))) {
    fprintf(stderr, "Usage: litefront-file-dialog file|folder|save [initial-folder] [filename]\n");
    return 1;
  }
  gboolean portuguese = argc > 4 && !strcmp(argv[4], "pt-PT");
  gboolean save = !strcmp(argv[1], "save");
  gboolean folder = !strcmp(argv[1], "folder");
  GError *error = NULL;
  GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
  if (!bus) {
    fprintf(stderr, "Cannot connect to the desktop: %s\n", error->message);
    g_error_free(error);
    return 1;
  }
  Dialog dialog = {g_main_loop_new(NULL, FALSE), NULL, 1};
  guint subscription = g_dbus_connection_signal_subscribe(bus,
    "org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
    NULL, NULL, G_DBUS_SIGNAL_FLAGS_NONE, response, &dialog, NULL);
  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  g_variant_builder_add(&options, "{sv}", "directory", g_variant_new_boolean(folder));
  g_variant_builder_add(&options, "{sv}", "multiple", g_variant_new_boolean(FALSE));
  g_variant_builder_add(&options, "{sv}", "modal", g_variant_new_boolean(TRUE));
  if (portuguese) g_variant_builder_add(&options, "{sv}", "accept_label", g_variant_new_string(save ? "Guardar" : "Abrir"));
  if (argc > 2 && *argv[2]) {
    g_variant_builder_add(&options, "{sv}", "current_folder",
      g_variant_new_fixed_array(G_VARIANT_TYPE_BYTE, argv[2], strlen(argv[2])+1, 1));
  }
  if (save && argc > 3 && *argv[3])
    g_variant_builder_add(&options, "{sv}", "current_name", g_variant_new_string(argv[3]));
  GVariant *reply = g_dbus_connection_call_sync(bus, "org.freedesktop.portal.Desktop",
    "/org/freedesktop/portal/desktop", "org.freedesktop.portal.FileChooser", save ? "SaveFile" : "OpenFile",
    g_variant_new("(ssa{sv})", "", portuguese ? (save ? "Guardar ficheiro" : (folder ? "Abrir pasta" : "Abrir ficheiro")) : (save ? "Save File" : (folder ? "Open Folder" : "Open File")), &options),
    G_VARIANT_TYPE("(o)"), G_DBUS_CALL_FLAGS_NONE, -1, NULL, &error);
  if (!reply) {
    fprintf(stderr, "Cannot open the system file dialog: %s\n", error->message);
    g_error_free(error);
  } else {
    g_variant_get(reply, "(o)", &dialog.request);
    g_variant_unref(reply);
    g_main_loop_run(dialog.loop);
  }
  g_dbus_connection_signal_unsubscribe(bus, subscription);
  g_free(dialog.request);
  g_main_loop_unref(dialog.loop);
  g_object_unref(bus);
  return dialog.status;
}
