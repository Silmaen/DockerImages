#!/usr/bin/env bash
#
# Shared setup for every builder image — THE build environment.
# Installs the toolchain-agnostic build tooling and all the -dev libraries, then
# both toolchains: gcc (stock version of the distro) and clang.
#
# The caller must export the toolchain versions before running this script:
#     export GCC_VERSION=14
#     export CLANG_VERSION=22
#     export CLANG_SOURCE=llvm        # or 'distro'
#     bash /tmp/install/_common/builder.sh

set -e

: "${GCC_VERSION:?GCC_VERSION must be set by the caller}"
: "${CLANG_VERSION:?CLANG_VERSION must be set by the caller}"

. /tmp/install/_common/helpers.sh

update_package_list
install_package ca-certificates curl gpg gnupg software-properties-common

# Kitware repo for an up-to-date cmake on every distro.
CODENAME="$(distro_codename)"
curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc \
  | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${CODENAME} main" \
  > /etc/apt/sources.list.d/kitware.list

update_package_list

# Build tools common to every toolchain.
install_package cmake cmake-data make ninja-build ccache mold patchelf \
                doxygen graphviz pkg-config time

# Development headers for libs the projects commonly link against
install_package libx11-dev libgtk-3-dev libssl-dev
# Full X11/XCB development set, as expected by Conan's xorg/system recipe, plus the
# Wayland headers and xkb-data. Required to build the Vulkan loader with every WSI
# backend (xlib, xcb, wayland) and xkbcommon with X11 support.
install_package libx11-dev libx11-xcb-dev libxcb1-dev libfontenc-dev libice-dev libsm-dev \
                libxau-dev libxaw7-dev libxcomposite-dev libxcursor-dev libxdamage-dev \
                libxdmcp-dev libxext-dev libxfixes-dev libxi-dev libxinerama-dev \
                libxkbfile-dev libxmu-dev libxmuu-dev libxpm-dev libxrandr-dev \
                libxrender-dev libxres-dev libxss-dev libxt-dev libxtst-dev libxv-dev \
                libxxf86vm-dev uuid-dev
install_package libxcb-glx0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-xkb-dev \
                libxcb-icccm4-dev libxcb-image0-dev libxcb-keysyms1-dev libxcb-randr0-dev \
                libxcb-shape0-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-xinerama0-dev \
                libxcb-dri3-dev libxcb-cursor-dev libxcb-dri2-0-dev libxcb-present-dev \
                libxcb-composite0-dev libxcb-ewmh-dev libxcb-res0-dev libxcb-util-dev
install_package libwayland-dev xkb-data
install_package libasound2-dev libpulse-dev libpipewire-0.3-dev libjack-dev \
                portaudio19-dev libmysofa-dev libsndfile1-dev
install_package libvulkan-dev vulkan-validationlayers libglfw3-dev

# Projects bring their own python tooling through poetry, nothing to add here.

clear_cache

# Both toolchains live in the same builder image: a CI job picks gcc or clang
# through CC/CXX without needing a different image. gcc comes first so that
# clang.sh finds libstdc++-${GCC_VERSION}-dev already installed.
bash /tmp/install/_common/gcc.sh
bash /tmp/install/_common/clang.sh

# Record the toolchain in the image so that the devel layer built on top does not
# have to repeat the versions (and cannot drift from them).
cat > /etc/ci-toolchain.env <<EOF
GCC_VERSION=${GCC_VERSION}
CLANG_VERSION=${CLANG_VERSION}
CLANG_SOURCE=${CLANG_SOURCE:-llvm}
EOF
