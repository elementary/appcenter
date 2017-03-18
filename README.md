# AppCenter

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* [cmake-elementary](https://code.launchpad.net/~elementary-os/+junk/cmake-modules)
* intltool
* libappstream-dev (>= 0.10)
* libgee-0.8-dev
* libgranite-dev
* libgtk-3-dev
* libpackagekit-glib2-dev
* libunity-dev
* libxml2-dev
* libxml2-utils
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
