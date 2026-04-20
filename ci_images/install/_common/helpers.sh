# Shared bash helpers sourced by every install script.
#
# Usage (from any install/<layer>/<name>.sh):
#     . /tmp/install/_common/helpers.sh
#
# Provides: update_package_list, install_package, clear_cache.
# Callers are expected to set `set -e` themselves.

update_package_list() {
  DEBIAN_FRONTEND=noninteractive apt update
}

install_package() {
  DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y "$@"
}

clear_cache() {
  DEBIAN_FRONTEND=noninteractive apt autoremove -y || true
  rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*
}
