#!/usr/bin/env bash
#
# Finalise a sysroot copied from a target image (see Dockerfile.cross).
#
# Absolute symlinks of the target filesystem (e.g. libfoo.so -> /lib/...) would
# resolve against the HOST root once the tree lives under ${SYSROOT}: rewrite
# them as relative links staying inside the sysroot. `realpath -s` keeps the
# computation lexical, so a not-yet-rewritten link in the middle of a path can
# never send it back to the host filesystem.

set -e

: "${SYSROOT:?SYSROOT must be set by the caller}"

find "${SYSROOT}" -type l -lname '/*' -exec sh -c '
  for link; do
    ln -sfn "$(realpath -ms --relative-to="$(dirname "$link")" "$0$(readlink "$link")")" "$link"
  done' "${SYSROOT}" {} +

# Nothing should still point outside the sysroot.
left=$(find "${SYSROOT}" -type l -lname '/*' | head -n 5)
if [[ -n "$left" ]]; then
  echo "ERROR: absolute symlinks left in ${SYSROOT}:" >&2
  echo "$left" >&2
  exit 1
fi
