#!/usr/bin/python2

import pyinotify
import os

class Monitor(pyinotify.ProcessEvent):
  def process_default(self, event):
    os.system("bash -c \"/home/winon/.winon/sani_handler.sh %s\"" % (event.pathname))

# These are the only two events that involve completion
mask = pyinotify.IN_MOVED_TO | \
    pyinotify.IN_CLOSE_WRITE

wm = pyinotify.WatchManager()
wm.add_watch("/home/winon/.winon/input", mask, proc_fun=Monitor())

notifier = pyinotify.Notifier(wm)
notifier.loop()
