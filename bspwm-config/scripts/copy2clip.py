#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf
import sys

path = sys.argv[1]

img = GdkPixbuf.Pixbuf.new_from_file(path)
clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
clipboard.set_image(img)
clipboard.store()
