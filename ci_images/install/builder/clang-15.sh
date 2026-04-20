#!/usr/bin/env bash
#
# Distro-variant clang-15 installer (uses Ubuntu 22.04 stock packages, NOT
# apt.llvm.org). All other clang builders (clang-llvm-N.sh) pull from
# apt.llvm.org ; this one keeps the stock distro toolchain.

set -e

bash /tmp/install/_common/builder.sh
. /tmp/install/_common/helpers.sh

update_package_list

install_package {clang,lld,llvm}-15 libstdc++-12-dev clang-tidy-15 libclang*-15-dev

update-alternatives --install /usr/bin/lld lld /usr/bin/lld-15 15
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 15
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 15
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-15 15
update-alternatives --install /usr/bin/llvm-cov llvm-cov /usr/bin/llvm-cov-15 15

clear_cache
