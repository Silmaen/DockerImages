#!/usr/bin/env bash
#
# Base image for Ubuntu 24.04 — RUNTIME ONLY.
# Contains Python, poetry, runtime libraries (no -dev headers), and common
# shell utilities. Designed to run the application and its test suite.
# Build tools (cmake, ninja, compilers, -dev libs) live in the builder layer.
#
# Note: Ubuntu 24.04 switched several libs to the "t64" ABI (64-bit time_t).
# We pin those names explicitly so this script never picks up the transitional
# stubs.

set -e

. /tmp/install/_common/helpers.sh

# Set timezone
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime

# The 24.04 upstream image ships a uid-1000 `ubuntu` account: rename it.
setup_default_user

update_package_list

install_package ca-certificates curl gpg gnupg tzdata locales
update-ca-certificates

# Python runtime + poetry for running app code and test suites
install_package python3 python3-pip python3-future python3-lxml python3-jinja2 \
                python3-requests-toolbelt

# Shell utilities and archive tools. p7zip only ships /usr/bin/7zr — p7zip-full
# is the one that provides the `7z` entry point (on 24.04 it is a transitional
# package pulling 7zip, which is fine: `7z` ends up available either way).
install_package git p7zip-full unzip time

# Full X11/XCB runtime set — mirrors the -dev list of _common/builder.sh
# (Conan's xorg/system recipe expects the whole suite). Keep both lists in sync.
install_package libx11-6 libx11-xcb1 libxcb1 libfontenc1 libice6 libsm6 \
                libxau6 libxaw7 libxcomposite1 libxcursor1 libxdamage1 \
                libxdmcp6 libxext6 libxfixes3 libxi6 libxinerama1 \
                libxkbfile1 libxmu6 libxmuu1 libxpm4 libxrandr2 \
                libxrender1 libxres1 libxss1 libxt6t64 libxtst6 libxv1 \
                libxxf86vm1 libuuid1
install_package libxcb-glx0 libxcb-render0 libxcb-render-util0 libxcb-xkb1 \
                libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
                libxcb-shape0 libxcb-sync1 libxcb-xfixes0 libxcb-xinerama0 \
                libxcb-dri3-0 libxcb-cursor0 libxcb-dri2-0 libxcb-present0 \
                libxcb-composite0 libxcb-ewmh2 libxcb-res0 libxcb-util1

# Wayland runtime + xkb-data (arch-independent keymap data, needed at runtime by
# xkbcommon) + libdecor, which glfw dlopens to decorate its Wayland windows:
# without it a Wayland window has no title bar at all.
install_package libwayland-client0 libwayland-cursor0 libwayland-egl1 \
                libwayland-server0 xkb-data libdecor-0-0

# Remaining runtime libraries (GUI toolkit, TLS, sound, Vulkan). t64-suffixed
# names on 24.04. The -dev counterparts are added by the builder layer.
install_package libgtk-3-0t64 libssl3t64 \
                libasound2t64 libpulse0 libpipewire-0.3-0 libjack-jackd2-0 \
                libportaudio2 libmysofa1 libsndfile1 \
                libvulkan1 vulkan-tools mesa-vulkan-drivers libglfw3

# Poetry — lives in /usr/poetry (referenced by Dockerfile's ENV PATH)
curl -sSL https://install.python-poetry.org | POETRY_HOME=/usr/poetry python3 -

# Locale
locale-gen C.UTF-8 en_US.UTF-8 || true

# Scratch cache dir owned by the default user
install -d -m 0755 -o user -g user /tmp/cache_dir

clear_cache
