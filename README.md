# AppCenter
[![Translation status](https://l10n.elementary.io/widgets/appcenter/-/svg-badge.svg)](https://l10n.elementary.io/projects/appcenter/?utm_source=widget)
[![Bountysource](https://www.bountysource.com/badge/tracker?tracker_id=57667267)](https://www.bountysource.com/teams/elementary/issues?tracker_ids=57667267)

An open, pay-what-you-want app store for indie developers.

![AppCenter Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* [cmake-elementary](https://github.com/elementary/cmake-modules)
* intltool
* libappstream-dev (>= 0.10)
* libgee-0.8-dev
* libgranite-dev
* libgtk-3-dev
* libjson-glib-dev
* libpackagekit-glib2-dev
* libsoup2.4-dev
* libunity-dev
* libxml2-dev
* libxml2-utils
* libsecret-1-dev (new)
* aescrypt (new) -> https://www.aescrypt.com/download/
* libgirepository1.0-dev
* AccountsService-1.0 
* libaccountsservice-dev 
* valac (>= 0.26)

It's recommended to create a clean build environment

    mkdir build
    cd build/

Run `cmake` to configure the build environment and then `make all test` to build and run automated tests

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make all test

To install, use `make install`, then execute with `appcenter`

    sudo make install
    appcenter

## Debugging

See debug messages:

    appcenter -d

Show restart required messaging:

    sudo touch /var/run/reboot-required

Hide restart required messaging:

    sudo rm /var/run/reboot-required
