#!/usr/bin/env bash

# Source environment variables
source .env

# Define output file
DC="docker compose"
function init(){
# Loop through nodes and create config files
# Define the base Redis service configuration
REDIS_DOCKER_COMPOSE_BASE="image: redis
    network_mode: host
    restart: always
    environment:
      - HOSTNAME={{HOSTNAME}}
    volumes:
      - ./{{CONF_PATH}}/redis.conf:/usr/local/etc/redis/redis.conf
      - ./{{DATA_PATH}}:/data
      - ./{{LOGS_PATH}}:/usr/local/redis/logs
    command: redis-server /usr/local/etc/redis/redis.conf
"
# Define the Redis service for each node and shard
REDUS_CONF_BASE="port {{PORT}}
requirepass {{PASSWD}}
masterauth {{PASSWD}}
protected-mode no
daemonize no
appendonly yes
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 15000
cluster-announce-ip {{HOST}}
cluster-announce-port {{PORT}}
cluster-announce-bus-port 1{{PORT}}
"
for n in $(seq 1 "$NG"); do
    SERVICES=""
    for s in $(seq 1 "$SS"); do

        if [ $s -le 9 ]; then
            PORT="700${s}"
        else
            PORT="70${s}"
        fi
        CONF_PATH="node${n}/${PORT}/conf"
        DATA_PATH="node${n}/${PORT}/data"
        LOGS_PATH="node${n}/${PORT}/logs"
        HOSTNAME="redis_n${n}s${s}"
        if [ -d "$(pwd)/node${n}/${PORT}" ]; then
            mv "$(pwd)/node${n}/${PORT}" "$(pwd)/node${n}/${PORT}_back_$(date "+%Y-%m-%d_%H:%M:%S")"
        fi
        varname="MGH${n}"
        HOST="${!varname}"
        mkdir -p "$CONF_PATH" "$DATA_PATH" "$LOGS_PATH"
        REDUS_CONF=$(echo "$REDUS_CONF_BASE" | sed "s/{{PORT}}/${PORT}/" | sed "s#{{HOST}}#${HOST}#" | sed "s#{{PASSWD}}#${PASSWORD}#")
        echo "${REDUS_CONF}"> "$CONF_PATH"/redis.conf
        REDIS_DOCKER_COMPOSE=$(echo "$REDIS_DOCKER_COMPOSE_BASE" | sed "s/{{HOSTNAME}}/${HOSTNAME}/" | sed "s#{{CONF_PATH}}#${CONF_PATH}#" | sed "s#{{DATA_PATH}}#${DATA_PATH}#" | sed "s#{{LOGS_PATH}}#${LOGS_PATH}#")
        SERVICES="${SERVICES}
  ${HOSTNAME}:
    ${REDIS_DOCKER_COMPOSE}"
    done
    # Generate the Docker Compose file
    echo "version: '3'
services:${SERVICES}"> docker-compose-node${n}.yml
done
}
function join(){
JOIN="redis-cli -h ${MGH1} -p 7001 -a ${PASSWORD} --cluster create \\"
for n in $(seq 1 "$NG"); do
    for s in $(seq 1 "$SS"); do
        if [ $s -le 9 ]; then
            PORT="700${s}"
        else
            PORT="70${s}"
        fi
        HOST="MGH${n}"
        JOIN="${JOIN} ${!HOST}:${PORT} \\"
    done
done
JOIN="${JOIN} --cluster-replicas ${NG}"
${JOIN}
}
start() {
    read -r -p "请选择启动节点: " node
    if [ -n "$node" ]; then
        ${DC} -f "docker-compose-node${node}.yml" up -d
    fi
    exit 0
}
stop() {
    read -r -p "请选择停止的节点: " node
    if [ -n "$node" ]; then
        ${DCV} -f "docker-compose-node${node}.yml" stop
    fi
    exit 0
}
restart() {
    read -r -p "请选择重启的节点: " node
    if [ -n "$node" ]; then
        ${DC} -f "docker-compose-node${node}.yml" restart
    fi
    exit 0
}
status() {
    read -r -p "请选择查看的节点: " node
    if [ -n "$node" ]; then
        ${DC} -f "docker-compose-node${node}.yml" ps
    fi
    exit 0
}
logs() {
    read -r -p "请选择查看的节点: " node
    if [ -n "$node" ]; then
        ${DC} -f "docker-compose-node${node}.yml" logs -f --tail 100
    fi
    exit 0
}
down() {
    read -r -p "请选择删除的节点: " node
    if [ -n "$node" ]; then
        ${DC} -f "docker-compose-node${node}.yml" down
    fi
    exit 0
}
check(){
  redis-cli -a ${PASSWORD} --cluster check ${MGH1}:7001
}
main() {
    echo -e "========================="
    echo -e "小翌REDIS集群管理"
    echo -e "========================="
    echo -e "0、初始化集群配置"
    echo -e "1、启动节点"
    echo -e "2、停止节点"
    echo -e "3、重启节点"
    echo -e "4、查看当前节点状态"
    echo -e "5、删除节点（数据保留）"
    echo -e "6、创建集群"
    echo -e "7、查看集群状态"
    echo -e "8、重置节点"
    echo -e "9、查看节点日志"
    echo -e "========================="
    read -r -p "请选选操作 (default: 7):" target

    if [ -z "$target" ]; then
        target=7
    fi
    if [ "${target}" = "0" ]; then
        init
    elif [ "${target}" = "1" ]; then
        start
    elif [ "${target}" = "2" ]; then
        stop
    elif [ "${target}" = "3" ]; then
        restart
    elif [ "${target}" = "4" ]; then
        status
    elif [ "${target}" = "5" ]; then
        down
    elif [ "${target}" = "6" ]; then
        join
    elif [ "${target}" = "7" ]; then
        check
    elif [ "${target}" = "8" ]; then
        clear
    elif [ "${target}" = "9" ]; then
        logs
    fi
}
main
