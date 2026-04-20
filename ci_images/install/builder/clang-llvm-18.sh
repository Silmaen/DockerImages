#!/usr/bin/env bash
set -e
bash /tmp/install/_common/builder.sh
export CLANG_VERSION=18
bash /tmp/install/_common/clang-llvm.sh
