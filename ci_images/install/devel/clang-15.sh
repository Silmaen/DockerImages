#!/usr/bin/env bash
#
# Devel image for the distro-variant clang-15 builder (Ubuntu 22.04 stock).

set -e

bash /tmp/install/_common/devel.sh

. /tmp/install/_common/helpers.sh

update_package_list
install_package lldb-15
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-15 15
clear_cache
