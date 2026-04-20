#!/usr/bin/env bash
#
# Builder image with GCC 12 (Ubuntu 22.04 stock).

set -e

bash /tmp/install/_common/builder.sh
. /tmp/install/_common/helpers.sh

update_package_list
install_package g++-12

update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-12 12
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12

clear_cache
