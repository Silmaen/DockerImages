#!/usr/bin/env bash
#
# Base image for Ubuntu 22.04 — RUNTIME ONLY.
# Contains Python, poetry, runtime libraries (no -dev headers), and common
# shell utilities. Designed to run the application and its test suite.
# Build tools (cmake, ninja, compilers, -dev libs) live in the builder layer.

set -e

. /tmp/install/_common/helpers.sh

# Set timezone
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime

# The 22.04 upstream image ships no uid-1000 account: create `user`.
setup_default_user

update_package_list

install_package ca-certificates curl gpg gnupg tzdata locales
update-ca-certificates

# Python runtime + poetry for running app code and test suites
install_package python3 python3-pip python3-future python3-lxml python3-jinja2 \
                python3-requests-toolbelt

# Shell utilities and archive tools. p7zip only ships /usr/bin/7zr, and the
# `7zip` package of 22.04 only ships /usr/bin/7zz — p7zip-full is the one that
# provides the `7z` entry point the other images have.
install_package git p7zip-full unzip time

# Full X11/XCB runtime set — mirrors the -dev list of _common/builder.sh
# (Conan's xorg/system recipe expects the whole suite). Keep both lists in sync.
install_package libx11-6 libx11-xcb1 libxcb1 libfontenc1 libice6 libsm6 \
                libxau6 libxaw7 libxcomposite1 libxcursor1 libxdamage1 \
                libxdmcp6 libxext6 libxfixes3 libxi6 libxinerama1 \
                libxkbfile1 libxmu6 libxmuu1 libxpm4 libxrandr2 \
                libxrender1 libxres1 libxss1 libxt6 libxtst6 libxv1 \
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

# Headless X server for GUI tests in CI: `xvfb-run ./tests`. xauth is what
# xvfb-run uses to set up the display cookie — spelled out so it never depends
# on recommends. x11-utils brings xdpyinfo / xwininfo / xprop, to inspect the
# display from a test script.
install_package xvfb xauth x11-utils

# libdecor-0-0 alone draws nothing: the decorations come from a plugin. 22.04
# ships libdecor 0.1.0, which only has the cairo plugin.
install_package libdecor-0-plugin-1-cairo

# OpenGL / EGL / GLES / GBM runtime. glfw and the Vulkan loader dlopen
# libEGL.so.1 and libGL.so.1 at runtime, and the Wayland backend goes through
# EGL + GBM. Without these, a binary that links or dlopens them builds fine in
# the builder and dies at runtime on the base. The -dev counterparts live in
# _common/builder.sh.
install_package libgl1 libglx0 libglvnd0 libegl1 libegl-mesa0 libgles2 \
                libgbm1 libopengl0

# Remaining runtime libraries (GUI toolkit, TLS, sound, Vulkan) — the -dev
# counterparts are added by the builder layer.
install_package libgtk-3-0 libssl3 \
                libasound2 libpulse0 libpipewire-0.3-0 libjack-jackd2-0 \
                libportaudio2 libmysofa1 libsndfile1 \
                libvulkan1 vulkan-tools mesa-vulkan-drivers libglfw3

# Poetry — lives in /usr/poetry (referenced by Dockerfile's ENV PATH)
curl -sSL https://install.python-poetry.org | POETRY_HOME=/usr/poetry python3 -

# Make python → python3
ln -sf /usr/bin/python3 /usr/bin/python

# Locale
locale-gen C.UTF-8 en_US.UTF-8 || true

# Scratch cache dir owned by the default user
install -d -m 0755 -o user -g user /tmp/cache_dir

clear_cache
