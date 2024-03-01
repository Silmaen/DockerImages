#!/usr/bin/env bash

# Stop if error
set -e

function update_package_list() {
  DEBIAN_FRONTEND=noninteractive apt update
}
function install_package() {
  DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y $@
}
function clear_cache() {
  DEBIAN_FRONTEND=noninteractive apt autoremove
  rm -rf /var/cache/apt/archive/* /var/lib/apt/lists/*
}

# update package list
update_package_list

# Install base packages
install_package {clang,lld}-17 clang-tidy-17

update-alternatives --install /usr/bin/lld lld /usr/bin/lld-17 17
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-17 17
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-17 17
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-17 17

# Clear the caches
clear_cache
