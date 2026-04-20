#!/usr/bin/env bash
#
# Shared setup for every builder image — installs everything that is required to
# *build* a project (toolchain-agnostic): build tools, -dev libraries, depmanager.
# Called from each builder/<compiler>.sh via `bash /tmp/install/_common/builder.sh`.

set -e

. /tmp/install/_common/helpers.sh

update_package_list
install_package ca-certificates curl gpg gnupg software-properties-common

# Kitware repo for an up-to-date cmake on every distro.
. /etc/os-release
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc \
  | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${CODENAME} main" \
  > /etc/apt/sources.list.d/kitware.list

update_package_list

# Build tools common to every toolchain
install_package cmake cmake-data make ninja-build ccache mold patchelf \
                doxygen graphviz pkg-config time

# Development headers for libs the projects commonly link against
install_package libx11-dev libgtk-3-dev libssl-dev
install_package libasound2-dev libpulse-dev libpipewire-0.3-dev libjack-dev \
                portaudio19-dev libmysofa-dev libsndfile1-dev
install_package libvulkan-dev vulkan-validationlayers libglfw3-dev

# Python helpers for the build (coverage report + dependency manager)
# PEP 668 (Ubuntu 24.04) requires --break-system-packages ; the flag is unknown
# on older pip (22.04) so we try once and fall back.
if ! pip install --break-system-packages --no-cache-dir depmanager gcovr 2>/dev/null; then
  pip install --no-cache-dir depmanager gcovr
fi

clear_cache
