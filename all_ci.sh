#!/bin/bash

set -e

# Ubuntu 22.04 images
./generator.py --preset base-ubuntu2204 --push --alias-latest
./generator.py --preset builder-gcc13-ubuntu2204 --push --alias-latest
./generator.py --preset builder-clang-llvm18-ubuntu2204 --push --alias-latest
./generator.py --preset devel-clang-llvm18-ubuntu2204 --push --alias-latest

# Ubuntu 24.04 images
./generator.py --preset base-ubuntu2404 --push --alias-latest
./generator.py --preset builder-gcc14-ubuntu2404 --push --alias-latest
./generator.py --preset builder-clang18-ubuntu2404 --push --alias-latest
./generator.py --preset devel-clang18-ubuntu2404 --push --alias-latest
