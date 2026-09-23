#!/usr/bin/env bash
#
# Base image for Ubuntu 26.04 — RUNTIME ONLY.
# Contains Python, poetry, runtime libraries (no -dev headers), and common
# shell utilities. Designed to run the application and its test suite.
# Build tools (cmake, ninja, compilers, -dev libs) live in the builder layer.
#
# Differences with 24.04:
#   - p7zip is gone from the archive, replaced by the `7zip` package.
#   - python3-future (a python2 compatibility shim) no longer exists.
#   - pipewire joined the "t64" ABI transition: libpipewire-0.3-0t64.

set -e

. /tmp/install/_common/helpers.sh

# Set timezone
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime

# The 26.04 upstream image ships a uid-1000 `ubuntu` account: rename it.
setup_default_user

update_package_list

install_package ca-certificates curl gpg gnupg tzdata locales
update-ca-certificates

# Python runtime + poetry for running app code and test suites
install_package python3 python3-pip python3-venv python3-lxml python3-jinja2 \
                python3-requests-toolbelt

# Shell utilities and archive tools. Unlike 22.04 / 24.04 there is no
# p7zip-full here: 26.04 dropped every p7zip* package, `7zip` is the only
# provider of /usr/bin/7z.
install_package git 7zip unzip time

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

# Headless X server for GUI tests in CI: `xvfb-run ./tests`. xauth is what
# xvfb-run uses to set up the display cookie — spelled out so it never depends
# on recommends. x11-utils brings xdpyinfo / xwininfo / xprop, to inspect the
# display from a test script.
install_package xvfb xauth x11-utils

# libdecor-0-0 alone draws nothing: the decorations come from a plugin. The gtk
# one matches the libgtk-3 already installed below.
install_package libdecor-0-plugin-1-gtk

# OpenGL / EGL / GLES / GBM runtime. glfw and the Vulkan loader dlopen
# libEGL.so.1 and libGL.so.1 at runtime, and the Wayland backend goes through
# EGL + GBM. Without these, a binary that links or dlopens them builds fine in
# the builder and dies at runtime on the base. The -dev counterparts live in
# _common/builder.sh.
install_package libgl1 libglx0 libglvnd0 libegl1 libegl-mesa0 libgles2 \
                libgbm1 libopengl0

# Remaining runtime libraries (GUI toolkit, TLS, sound, Vulkan). t64-suffixed
# names since 24.04. The -dev counterparts are added by the builder layer.
install_package libgtk-3-0t64 libssl3t64 \
                libasound2t64 libpulse0 libpipewire-0.3-0t64 libjack-jackd2-0 \
                libportaudio2 libmysofa1 libsndfile1 \
                libvulkan1 vulkan-tools mesa-vulkan-drivers libglfw3

# Poetry — lives in /usr/poetry (referenced by Dockerfile's ENV PATH)
curl -sSL https://install.python-poetry.org | POETRY_HOME=/usr/poetry python3 -

# Locale
locale-gen C.UTF-8 en_US.UTF-8 || true

# Scratch cache dir owned by the default user
install -d -m 0755 -o user -g user /tmp/cache_dir

clear_cache
