# Shared bash helpers sourced by every install script.
#
# Usage (from any install/<layer>/<name>.sh):
#     . /tmp/install/_common/helpers.sh
#
# Provides: update_package_list, install_package, clear_cache, distro_codename.
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

# Distro codename, usable for third-party apt repos (Kitware, apt.llvm.org).
# UBUNTU_CODENAME only exists on Ubuntu, VERSION_CODENAME is the Debian fallback.
distro_codename() {
  ( . /etc/os-release; echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}" )
}

# Point gcc/g++/cc/c++/gcov at one specific gcc version.
#
# `--force` is not optional here: several packages depend on the *unversioned*
# `gcc` meta-package (`lcov` does), which installs a real /usr/bin/gcc file and
# silently breaks the alternative link group — `update-alternatives --display`
# then still reports the pinned version while the file on disk is the distro
# default. Re-running this function after such an install repairs the group.
# Idempotent, so it is safe to call from every layer.
register_gcc_alternatives() {
  local version="$1"
  update-alternatives --force --install /usr/bin/gcc  gcc  "/usr/bin/gcc-${version}"  "${version}"
  update-alternatives --force --install /usr/bin/g++  g++  "/usr/bin/g++-${version}"  "${version}"
  update-alternatives --force --install /usr/bin/gcov gcov "/usr/bin/gcov-${version}" "${version}"
  # /usr/bin/cc and /usr/bin/c++ normally come from the unversioned gcc / g++
  # meta-packages, which we deliberately do not install (they would drag in the
  # distro's *default* gcc alongside the one we pin). Autotools configure
  # scripts and several package managers invoke cc / c++, so register them here.
  update-alternatives --force --install /usr/bin/cc   cc   "/usr/bin/gcc-${version}"  "${version}"
  update-alternatives --force --install /usr/bin/c++  c++  "/usr/bin/g++-${version}"  "${version}"
}

# Create the default `user` (the Dockerfile ends with `USER user`). Images that
# already ship a uid-1000 `ubuntu` account (>= 24.04) are renamed in place.
setup_default_user() {
  if getent passwd user > /dev/null; then
    return 0
  fi
  if getent passwd ubuntu > /dev/null; then
    usermod -l user -d /home/user -m ubuntu
    groupmod -n user ubuntu
  else
    useradd -m user
  fi
}
