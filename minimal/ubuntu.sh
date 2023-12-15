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

#set time zone
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime

# Create a user
useradd -m user

# update package list
update_package_list
# ----------------------------------------------------------------------------------------------------------------------
#                                               do install there

# ----------------------------------------------------------------------------------------------------------------------
# Clear the caches
clear_cache
