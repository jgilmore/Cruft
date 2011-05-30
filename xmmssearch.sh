#!/usr/bin/env python

# example entry.py

import pygtk
pygtk.require('2.0')
import gtk

class EntryExample:
    def done(self, widget, entry):
        randomize=self.randomize.get_active()
        repeat=self.repeat.get_active()
        regex=self.regex.get_text()
        gtk.main_quit()
        if repeat: 
            if randomize:
                playname="playrandom"
            else:
                playname="playme"
        else:
            if randomize:
                playname="playonce"
            else:
                playname="playmeonce"
        #print playname +" "+ regex
        import os
        os.execlp("/bin/bash","/bin/bash","-c","~/bin/" + playname + " " + regex)

    def ok(self, widget):
        self.done(widget, self.regex )

    def cancel(self, widget):
        gtk.main_quit()
        

    def __init__(self):
        # create a new window
        window = gtk.Window(gtk.WINDOW_TOPLEVEL)
        #window.set_size_request(200, 100)
        window.set_title("Play Music")
        window.set_size_request(400, 100)
        window.set_position(gtk.WIN_POS_CENTER)
        window.connect("delete_event", self.done)

        vbox = gtk.VBox(False, 0)
        window.add(vbox)
        vbox.show()

        entry = gtk.Entry()
        entry.set_max_length(50)
        entry.set_text("Rockapella")
        entry.select_region(0, len(entry.get_text()))
        entry.connect("activate", self.ok)
        vbox.pack_start(entry, True, True, 0)
        entry.show()
        self.regex=entry

        hbox = gtk.HBox(False, 0)
        vbox.add(hbox)
        hbox.show()
                                  
        check = gtk.CheckButton("Randomize")
        hbox.pack_start(check, True, True, 0)
        check.set_active(False)
        check.show()
        self.randomize=check
    
        check = gtk.CheckButton("Repeat")
        hbox.pack_start(check, True, True, 0)
        check.set_active(False)
        check.show()
        self.repeat=check

        hbox = gtk.HBox(False, 0)
        vbox.add(hbox)
        hbox.show()
                                   
        button = gtk.Button(stock=gtk.STOCK_CANCEL)
        button.connect("clicked", self.cancel)
        hbox.pack_start(button, True, True, 0)
        button.set_flags(gtk.CAN_DEFAULT)
        button.grab_default()
        button.show()

        button = gtk.Button(stock=gtk.STOCK_OK)
        button.connect("clicked", self.ok)
        hbox.pack_start(button, True, True, 0)
        button.set_flags(gtk.CAN_DEFAULT)
        button.grab_default()
        button.show()

        window.show()

def main():
    gtk.main()
    return 0

if __name__ == "__main__":
    EntryExample()
    main()
