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

# Runtime libraries (GUI, sound, Vulkan). t64-suffixed names since 24.04.
# libdecor is dlopened by glfw to decorate its windows on Wayland: without it a
# Wayland window has no title bar at all.
install_package libx11-6 libdecor-0-0 libgtk-3-0t64 libssl3t64 \
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
