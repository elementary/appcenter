# AppCenter
[![Translation status](https://l10n.elementary.io/widgets/appcenter/-/svg-badge.svg)](https://l10n.elementary.io/projects/appcenter/?utm_source=widget)

An open, pay-what-you-want app store for indie developers.

![AppCenter Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* gettext
* libadwaita-1-dev (>= 1.4)
* libappstream-dev (>= 1.0.0)
* libflatpak-dev (>= 1.0.7)
* libgee-0.8-dev
* libgranite-7-dev (>=7.6.0)
* libgtk-4-dev (>=4.10)
* libjson-glib-dev
* libpolkit-gobject-1-dev
* libportal-dev
* libportal-gtk4-dev
* libsoup-3.0-dev
* libxml2-dev
* libxml2-utils
* meson
* sassc
* valac (>= 0.26)

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `io.elementary.appcenter`

    ninja install
    io.elementary.appcenter --gapplication-replace

## Debugging

See debug messages:
As specified in the [GLib documentation](https://developer.gnome.org/glib/stable/glib-running.html)

    G_MESSAGES_DEBUG=all io.elementary.appcenter

Show restart required messaging:

    sudo touch /var/run/reboot-required

Hide restart required messaging:

    sudo rm /var/run/reboot-required

Load and preview a local AppStream XML metadata file, your local metadata will show up in the featured banner and will also be searchable. Metadata loaded this way will have a `(local)` suffix in it's name.

    io.elementary.appcenter --load-local /path/to/file.appdata.xml
