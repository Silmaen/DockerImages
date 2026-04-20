#!/usr/bin/env bash
#
# Devel image for an apt.llvm.org clang-19 builder. The apt.llvm.org repo is
# already configured by the builder parent, so we just install lldb-N.

set -e

bash /tmp/install/_common/devel.sh

. /tmp/install/_common/helpers.sh

update_package_list
install_package lldb-19
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-19 19
clear_cache
