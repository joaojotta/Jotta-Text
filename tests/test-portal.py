"""Run under dbus-run-session. Exercise the compiled helper against a mock desktop portal."""
import os
from pathlib import Path
import subprocess
import sys
import unittest
from gi.repository import Gio, GLib

XML = '''<node><interface name="org.freedesktop.portal.FileChooser">
<method name="OpenFile"><arg type="s" direction="in"/><arg type="s" direction="in"/>
<arg type="a{sv}" direction="in"/><arg type="o" direction="out"/></method>
<method name="SaveFile"><arg type="s" direction="in"/><arg type="s" direction="in"/>
<arg type="a{sv}" direction="in"/><arg type="o" direction="out"/></method>
</interface></node>'''
HELPER = str(Path(sys.argv.pop()).resolve())

class PortalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        cls.bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
            'org.freedesktop.DBus', 'RequestName',
            GLib.Variant('(su)', ('org.freedesktop.portal.Desktop', 0)), None,
            Gio.DBusCallFlags.NONE, -1, None)

    def run_dialog(self, mode, result, uri=None):
        self.seen = None
        def method(bus, sender, obj, interface, name, params, invocation):
            parent, title, options = params.unpack()
            self.seen = (title, options, name)
            request = '/org/freedesktop/portal/desktop/request/test/native'
            invocation.return_value(GLib.Variant('(o)', (request,)))
            def respond():
                values = {'uris': GLib.Variant('as', [uri])} if uri else {}
                bus.emit_signal(sender, request, 'org.freedesktop.portal.Request', 'Response',
                    GLib.Variant('(ua{sv})', (result, values)))
                return False
            GLib.timeout_add(10, respond)
        registration = self.bus.register_object('/org/freedesktop/portal/desktop',
            Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0], method, None, None)
        child = subprocess.Popen([HELPER, mode, '/tmp/space folder', 'example.txt'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        loop = GLib.MainLoop()
        def check():
            if child.poll() is not None:
                loop.quit()
                return False
            return True
        GLib.timeout_add(10, check)
        def expire():
            child.kill()
            loop.quit()
            return False
        timeout = GLib.timeout_add_seconds(5, expire)
        loop.run()
        GLib.source_remove(timeout)
        self.bus.unregister_object(registration)
        stdout, stderr = child.communicate(timeout=2)
        self.assertIsNotNone(self.seen, stderr)
        self.assertEqual(self.seen[0], 'Save File' if mode == 'save' else ('Open Folder' if mode == 'folder' else 'Open File'))
        self.assertEqual(self.seen[1]['directory'], mode == 'folder')
        self.assertFalse(self.seen[1]['multiple'])
        self.assertEqual(self.seen[2], 'SaveFile' if mode=='save' else 'OpenFile')
        if mode=='save': self.assertEqual(self.seen[1]['current_name'], 'example.txt')
        return child.returncode, stdout

    def test_file_names_are_preserved(self):
        name = Path('/tmp/a file "quoted"\nwith unicode ç.html')
        self.assertEqual(self.run_dialog('file', 0, name.as_uri()), (0, os.fsencode(name)))

    def test_folder_selection(self):
        self.assertEqual(self.run_dialog('folder', 0, 'file:///tmp/project'), (0, b'/tmp/project'))

    def test_save_new_file(self):
        self.assertEqual(self.run_dialog('save', 0, 'file:///tmp/new%20file.txt'), (0, b'/tmp/new file.txt'))

    def test_cancel_save(self):
        self.assertEqual(self.run_dialog('save', 1), (2, b''))

    def test_cancel(self):
        self.assertEqual(self.run_dialog('file', 1), (2, b''))

    def test_missing_selection(self):
        self.assertEqual(self.run_dialog('file', 0), (1, b''))

    def test_remote_uri_is_rejected(self):
        code, output = self.run_dialog('file', 0, 'https://example.com/file')
        self.assertEqual((code, output), (1, b''))

if __name__ == '__main__':
    unittest.main()
