#!/usr/bin/env bash

set -ex

killall io.elementary.appcenter || true
VERSION="$(dpkg-parsechangelog -S Version)"
debuild -b -uc -us -nc
sudo dpkg -i "../pop-shop_${VERSION}_amd64.deb"
io.elementary.appcenter
