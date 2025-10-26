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
# Add the PPA for GCC 13
install_package software-properties-common wget
add-apt-repository -y ppa:ubuntu-toolchain-r/test

# Install base packages
install_package g++-13

update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-13 13
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 13
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 13

# Clear the caches
clear_cache
