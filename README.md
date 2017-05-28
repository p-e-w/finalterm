### :bangbang: Final Term is no longer being actively developed. The official discontinuation announcement can be found at http://worldwidemann.com/finally-terminated. :bangbang:

<br><br><br>

# About Final Term

Final Term is a new breed of terminal emulator.

![Screencast](http://finalterm.org/screencast.gif)

It goes beyond mere emulation and understands what is happening inside the shell it is hosting. This allows it to offer features no other terminal can, including:

* Semantic text menus
* Smart command completion
* GUI terminal controls

For more information, visit [http://finalterm.org](http://finalterm.org).

# Installation

Final Term is written in [Vala](https://live.gnome.org/Vala) and built on top of [GTK+ 3](http://www.gtk.org), [Clutter](http://blogs.gnome.org/clutter/) and [Mx](https://github.com/clutter-project/mx). It requires the development files for the following software packages:

* [Gee](https://live.gnome.org/Libgee)
* [GTK+ 3](http://www.gtk.org)
* [Clutter](http://blogs.gnome.org/clutter/) >= 1.12
* [Clutter-Gtk](http://blogs.gnome.org/clutter/)
* [Mx](https://github.com/clutter-project/mx)
* [keybinder-3.0](https://github.com/engla/keybinder/tree/keybinder-3.0)
* [libnotify](https://developer.gnome.org/libnotify/) _Optional_, for desktop notifications support
* [libunity](https://launchpad.net/libunity) _Optional_, for Unity launcher integration (progress bars)

Additionally, it requires [intltool](http://freedesktop.org/wiki/Software/intltool/) for localization string extraction.

To install Final Term, execute these shell commands:

```sh
git clone https://github.com/p-e-w/finalterm.git
cd finalterm/
mkdir build
cd build/
cmake ..
make
sudo make install
```

If you want to install to a custom directory your `XDG_DATA_DIRS` environment variable has to point to the prefix with the file `glib-2.0/schemas/gschemas.compiled` in it.

## Instructions for Ubuntu

Thanks to the work of Bob Mottram (packaging) and GitHub user versable (PPA setup), Ubuntu is currently the easiest platform to install Final Term on:

```sh
sudo add-apt-repository ppa:finalterm/daily
sudo apt-get update
sudo apt-get install finalterm
```

The PPA is synchronized with the GitHub repository and should always deliver the latest version with a few hours delay at most.

### Prerequisites to build from source (Ubuntu/Debian)
To install build environment, vala compiler:
```
sudo apt-get install build-essential cmake valac intltool
```
To install all required libraries:
```
sudo apt-get install libgee-0.8-dev libkeybinder-3.0-dev libmx-1.0-2 libclutter-gtk-1.0-dev libnotify-dev libunity-dev
```

## Instructions for Fedora

You can use packages from [Copr by Matthew Miller](http://copr.fedoraproject.org/coprs/mattdm/finalterm/).

### Fedora 19

```
sudo wget http://copr.fedoraproject.org/coprs/mattdm/finalterm/repo/fedora-19-i386/mattdm-finalterm-fedora-19-i386.repo -O /etc/yum.repos.d/finalterm.repo
sudo yum update
sudo yum install finalterm
```

### Fedora 20

```
sudo wget http://copr.fedoraproject.org/coprs/mattdm/finalterm/repo/fedora-20-i386/mattdm-finalterm-fedora-20-i386.repo -O /etc/yum.repos.d/finalterm.repo
sudo yum update
sudo yum install finalterm
```

### Fedora Rawhide

```
sudo wget http://copr.fedoraproject.org/coprs/mattdm/finalterm/repo/fedora-rawhide-i386/mattdm-finalterm-fedora-rawhide-i386.repo -O /etc/yum.repos.d/finalterm.repo
sudo yum update
sudo yum install finalterm
```

## Instructions for Arch Linux

There is an AUR for Final Term maintained by Arch Linux user kens: [https://aur.archlinux.org/packages/finalterm-git/](https://aur.archlinux.org/packages/finalterm-git/).

## Instructions for Gentoo

A [live ebuild for Final Term](http://git.overlays.gentoo.org/gitweb/?p=proj/sunrise-reviewed.git;a=tree;f=x11-terms/finalterm;hb=HEAD) is in Gentoo's Sunrise overlay courtesy of Ferenc Erki. You can find [usage instructions here](https://wiki.gentoo.org/wiki/Project:Sunrise).

# Acknowledgments

Final Term owes much of its existence to the awesomeness of [Vala](https://live.gnome.org/Vala) and [its documentation](http://valadoc.org), [Clutter](http://blogs.gnome.org/clutter/) and [Mx](https://github.com/clutter-project/mx), as well as to those projects authors' generous decision to release their amazing work as open source software.

Much of the knowledge about terminal emulation required to build Final Term was gained from [the xterm specification](http://invisible-island.net/xterm/ctlseqs/ctlseqs.html) and the [VT100 User Guide](http://vt100.net/docs/vt100-ug/contents.html), as well as from the study of existing terminal emulators such as [st](http://st.suckless.org) and [Terminator](http://software.jessies.org/terminator/).

Final Term's color schemes are generated using the wonderful [Base16 Builder](https://github.com/chriskempson/base16-builder) by Chris Kempson.

Final Term's application icon is a modified version of the terminal icon from the [Faenza icon theme](http://tiheum.deviantart.com/art/Faenza-Icons-173323228) by Matthieu James.

# License

Copyright © 2013–2014 Philipp Emanuel Weidmann (<pew@worldwidemann.com>)

Final Term is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Final Term is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Final Term.  If not, see <http://www.gnu.org/licenses/>.
