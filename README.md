# About Final Term

Final Term is a new breed of terminal emulator.

It goes beyond mere emulation and understands what is happening inside the shell it is hosting. This allows it to offer features no other terminal can, including:

* Semantic text menus
* Smart command completion
* GUI terminal controls

For more information, screenshots and a demonstration video, visit [http://finalterm.org](http://finalterm.org).

# Installation

Final Term is written in [Vala](https://live.gnome.org/Vala) and built on top of [GTK+ 3](http://www.gtk.org), [Clutter](http://blogs.gnome.org/clutter/) and [Mx](https://github.com/clutter-project/mx). It requires the development files for the following software packages:

* [Gee](https://live.gnome.org/Libgee)
* [GTK+ 3](http://www.gtk.org)
* [Clutter](http://blogs.gnome.org/clutter/)
* [Clutter-Gtk](http://blogs.gnome.org/clutter/)
* [Mx](https://github.com/clutter-project/mx)
* [keybinder-3.0](https://github.com/engla/keybinder/tree/keybinder-3.0)

To install Final Term, execute these shell commands:

```
git clone https://github.com/p-e-w/finalterm.git
cd finalterm
make
```

Then, run Final Term using

```
./finalterm
```

## Instructions for Fedora

The following concrete steps have been tested and work to get Final Term installed and running on a vanilla Fedora 18 system:

### Install prerequisites

```
sudo yum install git vala libgee-devel gnome-common gtk-doc gtk3-devel libmx-devel clutter-gtk-devel
```

### Install keybinder-3.0

Note that the Fedora repositories only contain the package "keybinder", which is linked against GTK+ 2.

```
git clone https://github.com/engla/keybinder.git
cd keybinder/
git checkout keybinder-3.0
./autogen.sh
make
sudo make install
```

### Install Final Term

```
git clone https://github.com/p-e-w/finalterm.git
cd finalterm/
make
```

#### If keybinder cannot be found

Unfortunately, the keybinder install script fails to install the Vala bindings properly. To fix this, in the keybinder root directory, execute:

```
sudo cp examples/keybinder.vapi /usr/share/vala/vapi/
```

#### If keybinder still cannot be found

On Fedora there are sometimes further problems locating the keybinder library. To work around those, execute:

```
sudo cp /usr/local/include/keybinder-3.0/keybinder.h /usr/include/
sudo cp /usr/local/lib/libkeybinder-3.0.* /usr/lib/
```

#### If there is an "error while loading shared libraries" when starting Final Term

```
sudo ldconfig
```

## Instructions for Ubuntu

The following concrete steps have been tested and work to get Final Term installed and running on a vanilla Ubuntu 12.10 ("Quantal Quetzal") system:

### Add Vala repository

This is necessary because Ubuntu does not provide an up-to-date version of Vala in its default repositories.

```
sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 7DAAC99C
sudo add-apt-repository ppa:vala-team
```

### Install prerequisites

```
sudo apt-get install git valac-0.18 libgee-0.8 libmx-dev libclutter-gtk-1.0-dev keybinder-3.0-dev
```

### Install Vala bindings for keybinder-3.0

Unfortunately, the package "keybinder-3.0-dev" does not contain Vala bindings, so those have to be installed manually:

```
git clone https://github.com/engla/keybinder.git
cd keybinder/
git checkout keybinder-3.0
sudo cp examples/keybinder.vapi /usr/share/vala/vapi/
```

### Install Final Term

```
git clone https://github.com/p-e-w/finalterm.git
cd finalterm/
make
```

#### If keybinder.h cannot be found

As on Fedora, for unknown reasons the Vala compiler can have problems locating keybinder.h. To fix this, execute:

```
sudo cp /usr/include/keybinder-3.0/keybinder.h /usr/include/
```

#### If there is an "error while loading shared libraries" when starting Final Term

```
sudo ldconfig
```

#### If there is a "Gtk-ERROR **: GTK+ 2.x symbols detected" when starting Final Term

This probably means that you are on Ubuntu 13.04 ("Raring Ringtail"), as reported in https://github.com/p-e-w/finalterm/issues/17.

The solution (for now, until I find something better) is to replace the line

```
--pkg keybinder
```

with

```
--pkg keybinder-3.0
```

in `Makefile`, and recompile. Unfortunately, doing this breaks compilation on some other platforms so I cannot make it the default yet.

# Acknowledgments

Final Term owes much of its existence to the awesomeness of [Vala](https://live.gnome.org/Vala) and [its documentation](http://valadoc.org), [Clutter](http://blogs.gnome.org/clutter/) and [Mx](https://github.com/clutter-project/mx), as well as to those projects authors' generous decision to release their amazing work as open source software.

Much of the knowledge about terminal emulation required to build Final Term was gained from [the xterm specification](http://invisible-island.net/xterm/ctlseqs/ctlseqs.html) and the [VT100 User Guide](http://vt100.net/docs/vt100-ug/contents.html), as well as from the study of existing terminal emulators such as [st](http://st.suckless.org) and [Terminator](http://software.jessies.org/terminator/).

Final Term's color schemes are generated using the wonderful [Base16 Builder](https://github.com/chriskempson/base16-builder) by Chris Kempson.

Final Term's application icon is a modified version of the terminal icon from the [Faenza icon theme](http://tiheum.deviantart.com/art/Faenza-Icons-173323228) by Matthieu James.

# License

Copyright © 2013 Philipp Emanuel Weidmann (<pew@worldwidemann.com>)

Final Term is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Final Term is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Final Term.  If not, see <http://www.gnu.org/licenses/>.
