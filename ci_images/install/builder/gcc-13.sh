#!/usr/bin/env bash
#
# Builder image with GCC 13 on Ubuntu 22.04 (via ppa:ubuntu-toolchain-r/test).
# Note: on Ubuntu 24.04, g++-13 is native ; this script still works but the PPA
# step is redundant.

set -e

bash /tmp/install/_common/builder.sh
. /tmp/install/_common/helpers.sh

# PPA for GCC 13 on Ubuntu 22.04 (no-op / duplicate on distros that already
# ship a recent g++-13 package)
add-apt-repository -y ppa:ubuntu-toolchain-r/test
update_package_list

install_package g++-13

update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-13 13
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 13
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 13

clear_cache
