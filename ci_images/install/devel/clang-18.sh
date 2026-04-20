#!/usr/bin/env bash
#
# Devel image for the distro-variant clang-18 builder (Ubuntu 24.04 stock).

set -e

bash /tmp/install/_common/devel.sh

. /tmp/install/_common/helpers.sh

update_package_list
install_package lldb-18
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-18 18
clear_cache
