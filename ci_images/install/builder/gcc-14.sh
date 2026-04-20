#!/usr/bin/env bash
#
# Builder image with GCC 14 (Ubuntu 24.04 stock).

set -e

bash /tmp/install/_common/builder.sh
. /tmp/install/_common/helpers.sh

update_package_list
install_package g++-14

update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-14 14
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 14
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 14

clear_cache
