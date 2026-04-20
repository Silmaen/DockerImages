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

# Create the default user (22.04 upstream images don't ship one)
useradd -m user

update_package_list

install_package ca-certificates curl gpg gnupg tzdata locales
update-ca-certificates

# Python runtime + poetry for running app code and test suites
install_package python3 python3-pip python3-future python3-lxml python3-jinja2 \
                python3-requests-toolbelt

# Shell utilities and archive tools
install_package git p7zip unzip time

# Runtime libraries (GUI, sound, Vulkan) — the -dev counterparts are added by
# the builder layer and pull the same SONAMEs via apt dependency resolution.
install_package libx11-6 libgtk-3-0 libssl3 \
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
