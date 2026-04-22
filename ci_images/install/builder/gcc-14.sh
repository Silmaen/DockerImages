#!/usr/bin/env bash
#
# Builder image avec GCC 14 (max natif dans Ubuntu 24.04 universe).
# Garantit que les binaires produits linkent libstdc++6 14.2.0, version
# shipped dans Ubuntu 24.04 main → aucun paquet hors repos officiels à
# installer sur la target pour exécuter.

set -e

bash /tmp/install/_common/builder.sh
. /tmp/install/_common/helpers.sh

update_package_list
install_package g++-14

update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-14 14
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 14
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 14

clear_cache
