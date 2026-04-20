#!/usr/bin/env bash
#
# Devel image for an apt.llvm.org clang-16 builder. The apt.llvm.org repo is
# already configured by the builder parent, so we just install lldb-N.

set -e

bash /tmp/install/_common/devel.sh

. /tmp/install/_common/helpers.sh

update_package_list
install_package lldb-16
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-16 16
clear_cache
