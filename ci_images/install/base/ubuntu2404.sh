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

# Remove default user
userdel -r ubuntu
# Create a user
useradd -m user

# update package list
update_package_list

# Install base packages
install_package python3 python3-future python3-lxml python3-jinja2 python3-pip python3-requests-toolbelt p7zip unzip time patchelf cmake cmake-data make ninja-build ccache doxygen graphviz mold gcovr git

# create a default cache dir
[ ! -e /tmp/cache_dir ] && install -d -m 0755 -o user -g user /tmp/cache_dir

# install dependency manager
pip install depmanager --break-system-packages

# Install dev libraries
install_package libx11-dev libgtk-3-dev libssl-dev

# Install dev libraries for sound
install_package libasound2-dev libpulse-dev libpipewire-0.3-dev libjack-dev portaudio19-dev libmysofa-dev libsndfile1-dev

# Clear the caches
clear_cache
