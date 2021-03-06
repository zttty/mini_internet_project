#!/bin/bash
#
# delete links between groups and matrix container

set -o errexit
set -o pipefail
set -o nounset

DIRECTORY="$1"
source "${DIRECTORY}"/config/subnet_config.sh

# read configs
readarray groups < "${DIRECTORY}"/config/AS_config.txt
group_numbers=${#groups[@]}

echo -n "-- --if-exists del-br matrix " >> "${DIRECTORY}"/ovs_command.txt
