#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

DIRECTORY="$1"
source "${DIRECTORY}"/config/subnet_config.sh
source "${DIRECTORY}"/setup/ovs-docker.sh

# read configs
readarray groups < "${DIRECTORY}"/config/AS_config.txt
group_numbers=${#groups[@]}

# Layer2 connectivity
for ((k=0;k<group_numbers;k++)); do
    group_k=(${groups[$k]})
    group_number="${group_k[0]}"
    group_as="${group_k[1]}"
    group_router_config="${group_k[3]}"
    group_internal_links="${group_k[4]}"
    group_layer2_switches="${group_k[5]}"
    group_layer2_hosts="${group_k[6]}"
    group_layer2_links="${group_k[7]}"

    if [ "${group_as}" != "IXP" ];then

        readarray routers < "${DIRECTORY}"/config/$group_router_config
        n_routers=${#routers[@]}

        br_name_api=${group_number}"-p4api"
        echo -n "-- add-br "${br_name_api}" " >> "${DIRECTORY}"/groups/add_bridges.sh

        # start routers and hosts
        for ((i=0;i<n_routers;i++)); do
            router_i=(${routers[$i]})
            rname="${router_i[0]}"
            rtype="${router_i[1]}"
            property1="${router_i[2]}"
            property2="${router_i[3]}"
            dname=$(echo $property2 | cut -d ':' -f 2)

            if [ "$rtype" == "bmv2_simple_switch" ] || [ "$rtype" == "bmv2_simple_switch_opt" ]; then
                subnet_p4api="$(subnet_p4api "${group_number}" "p4router" "${i}")"

                ./setup/ovs-docker.sh add-port "${br_name_api}" "switch-api" \
                "${group_number}""_""${rname}""router" --ipaddress="${subnet_p4api}"

                echo "ip link add ${group_number}-$rname-cpu type veth peer name switch-cpu" >> "${DIRECTORY}"/groups/ip_setup.sh
                echo "ip link set dev ${group_number}-$rname-cpu up" >> "${DIRECTORY}"/groups/ip_setup.sh
                get_docker_pid "${group_number}""_""${rname}""router"
                echo "PID=$DOCKER_PID" >> "${DIRECTORY}"/groups/ip_setup.sh
                echo "create_netns_link" >> "${DIRECTORY}"/groups/ip_setup.sh
                echo "ip link set switch-cpu netns \$PID" >> "${DIRECTORY}"/groups/ip_setup.sh
                echo "ip link set dev ${group_number}-$rname-cpu up" >> "${DIRECTORY}"/groups/ip_setup.sh
                echo "docker exec -d "${group_number}"_"${rname}"router ip link set dev switch-cpu up" >> "${DIRECTORY}"/groups/ip_setup.sh
            fi

        done

        subnet_p4api_controller="$(subnet_p4api "${group_number}" "controller" "${i}")"

        echo "ip link add ${group_number}-p4switch-api type veth peer name g${group_number}-p4switch-api" >> "${DIRECTORY}"/groups/ip_setup.sh
        echo "ip link set dev ${group_number}-p4switch-api up" >> "${DIRECTORY}"/groups/ip_setup.sh
        echo "ip link set dev g${group_number}-p4switch-api up" >> "${DIRECTORY}"/groups/ip_setup.sh
        echo "ovs-vsctl add-port "${br_name_api}" g${group_number}-p4switch-api" >> "${DIRECTORY}"/groups/ip_setup.sh
        echo "ip addr add "$subnet_p4api_controller" dev ${group_number}-p4switch-api" >> "${DIRECTORY}"/groups/ip_setup.sh
    fi
done