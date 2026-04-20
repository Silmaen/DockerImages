#!/usr/bin/env bash
#
# Devel image for any GCC-based builder. All the heavy lifting (gdb, valgrind,
# profilers, quality-of-life tools) is in _common/devel.sh — GCC needs no
# version-specific debugger (gdb handles every supported gcc-N).

set -e

bash /tmp/install/_common/devel.sh
