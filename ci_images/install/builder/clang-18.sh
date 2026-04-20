#!/usr/bin/env bash
#
# Distro-variant clang-18 installer (uses Ubuntu 24.04 stock packages, NOT
# apt.llvm.org). All other clang builders (clang-llvm-N.sh) pull from
# apt.llvm.org ; this one keeps the stock distro toolchain so the runtime
# ABI matches Ubuntu 24.04 exactly.

set -e

bash /tmp/install/_common/builder.sh
. /tmp/install/_common/helpers.sh

update_package_list

install_package {clang,lld,llvm}-18 clang-tidy-18 libclang-rt-18-dev

update-alternatives --install /usr/bin/lld lld /usr/bin/lld-18 18
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 18
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 18
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-18 18
update-alternatives --install /usr/bin/llvm-cov llvm-cov /usr/bin/llvm-cov-18 18

clear_cache
