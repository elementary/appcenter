# AppCenter

## Building and Installation

In order to build this software, you need the latest version of [cmake-elementary](https://code.launchpad.net/~elementary-os/+junk/cmake-modules)

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`, then execute with `appcenter`

    sudo make install
    appcenter
