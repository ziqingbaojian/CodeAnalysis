#!/bin/bash

CURRENT_SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")";pwd)  # 获取当前的绝对路径
TCA_SCRIPT_ROOT=${TCA_SCRIPT_ROOT:-"$( cd "$(dirname $CURRENT_SCRIPT_PATH)"; pwd )"}

source $TCA_SCRIPT_ROOT/utils.sh  # 导入 utils.sh

export DOCKER_INSTALL_FILE=${DOCKER_INSTALL_FILE:-/tmp/get-docker.sh}  # 设置环境变量默认值 get-docker.sh

function check_docker() {
    ret=""
    # 检查 docker 命令是否存在, 根据返回值看, 成功的返回值为 0;
    if command_exists docker; then
        ret="true"
    else
        ret="false"
    fi
    echo "$ret"
}

# 检查 docker compose 是否存在,根据返回值状态码确定
function check_docker_compose() {
    ret=""
    if command_exists docker-compose; then
        ret="true"
    else
        ret="false"
    fi
    echo "$ret"
}

# 检查 docker ps 命令能能否正常运行;
function check_docker_service() {
    docker ps -q &>/dev/null  # 列出正在运行的容器id, 输出到黑洞文件;
    if [ "$?" == "0" ]; then
        ret="true"
    else
        ret="false"
    fi
    echo "$ret"
}

# 启动docker 服务;
function start_docker_service() {
    LOG_INFO "Start Docker service"
    
    ret=$( check_docker_service )  # 检查 docker 是否存在,已经启动;
    if [ "$ret" == "true" ]; then
        LOG_INFO "* Docker had started"
        return 0
    fi

    systemctl restart docker  # 重启 docker 的服务;
    start_docker_exit_code=$?  # 使用 $? 获取上一条命令是否执行成功

    if [ "$start_docker_exit_code" = "0" ]; then
        LOG_INFO "* Start Docker success"  # 成功重启了 docker
        return 0
    else
        # docker 启动失败;
        LOG_ERROR "Start Docker failed. Please check log"
        return 1
    fi
}

# 快速安装 docker
function quiet_install_docker() {
    ret=$( check_docker )  # 检查 docker 的服务;
    if [ "$ret" == "true" ]; then
        LOG_WARN "This machine had installed docker"  # 已经存在, 无需安装;
    else
        # 不存在,
        LOG_INFO "Download docker and install"
        # 进行 docker 的安装;

        # 1. 下载官方指定的安装 docker 的 shell 脚本文件;
        curl -fsSL https://get.docker.com -o $DOCKER_INSTALL_FILE
        sh $DOCKER_INSTALL_FILE  # 执行安装的脚本;
        rm $DOCKER_INSTALL_FILE  # 删除脚本;
    fi

    check_docker_service  # 在此检查 docker 是否存在;
    if [ "$?" -ne 0 ] ; then
        start_docker_service  # 安装完成, 启动 docker 服务;
    fi
}

function quiet_install_docker_compose() {
    ret=$( check_docker_compose )
    if [ "$ret" == "true" ]; then
        LOG_WARN "This machine had installed docker_compose"
        return 0
    fi

    LOG_INFO "Download docker-compose and install"
    docker_compose_url="https://github.com/docker/compose/releases/download/1.27.2/docker-compose-$(uname -s)-$(uname -m)"
    curl -L ${docker_compose_url} -o /usr/local/bin/docker-compose
    retval=$?
    chmod +x /usr/local/bin/docker-compose
    if [ "$retval" -ne 0 ]; then
        LOG_WARN "Download docker-compose failed." 
        LOG_WARN "Please download manually, url: ${docker_compose_url}"
        LOG_WARN "  After download, copy to /usr/loca/bin/ and execute command: chmod +x /usr/local/bin/docker-compose"
        LOG_WARN "  docker-compose install Tutorial: https://docs.docker.com/compose/install/#install-compose-on-linux-systems"
        exit 1; 
    fi
}

# 安装 docker 函数的封装;
function interactive_install_docker() {
    ret=$( check_docker )
    status=$( check_docker_service )
    if [ "$ret" == "true" ]; then
        if [ "$status" == "true" ]; then
            return 0
        else
            start_docker_service || error_exit "Start docker service failed"
            sleep 5
            return 0
        fi
    fi
    LOG_WARN "Deploying TCA with docker/docker-compose depends on docker. Current machine has not installed docker."
    LOG_INFO "Do you want to install [Docker] by this script?"
    read -p "Please enter:[Y/N]" result
    case $result in
            [yY])
                sleep 2
                quiet_install_docker
                ;;
            [nN])
                echo -e "Cancel install docker"
                return 1
                ;;
            *)
                LOG_ERROR "Invalid input. Stop."
                exit 1
                ;;
        esac
}

# 安装 docker  compose 函数的封装;
function interactive_install_docker_compose() {
    ret=$( check_docker_compose )
    if [ "$ret" == "true" ]; then
        return 0
    fi

    LOG_WARN "Deploying TCA with docker/docker-compose depends on docker. Current machine has not installed docker-compose."
    LOG_INFO "Do you want to install docker-compose by this script?"
    read -p "Please enter:[Y/N]" result
    case $result in
            [yY])
                sleep 2
                quiet_install_docker_compose
                ;;
            [nN])
                echo -e "Cancel install docker_compose"
                return 1
                ;;
            *)
                LOG_ERROR "Invalid input. Stop."
                exit 1
                ;;
        esac
}
