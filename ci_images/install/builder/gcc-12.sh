#!/usr/bin/env bash
#
# Builder image avec GCC 12 (max natif dans Ubuntu 22.04 main).
# Garantit que les binaires produits linkent libstdc++6 12.3.0, version
# shipped dans Ubuntu 22.04 main → aucun paquet hors repos officiels à
# installer sur la target pour exécuter.

set -e

bash /tmp/install/_common/builder.sh
. /tmp/install/_common/helpers.sh

update_package_list
install_package g++-12

update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-12 12
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12

clear_cache
