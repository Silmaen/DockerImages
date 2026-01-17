#!/usr/bin/env bash

# Stop if error
set -e

function update_package_list() {
  DEBIAN_FRONTEND=noninteractive apt update
}
function install_package() {
  DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y "$@"
}
function clear_cache() {
  DEBIAN_FRONTEND=noninteractive apt autoremove
  rm -rf /var/cache/apt/archive/* /var/lib/apt/lists/*
}

# update package list
update_package_list

# Install base packages
install_package lldb gdb valgrind gperf

# Clear the caches
clear_cache