#!/bin/bash


CURRENT_SCRIPT_PATH=$( cd "$(dirname ${BASH_SOURCE[0]})"; pwd )  # 获取路径
# 设置路径导入到环境变量;
export TCA_SCRIPT_ROOT=${TCA_SCRIPT_ROOT:-"$( cd $(dirname $CURRENT_SCRIPT_PATH); pwd )"}
export TCA_PROJECT_PATH=${TCA_PROJECT_PATH:-"$( cd $(dirname $TCA_SCRIPT_ROOT); pwd )"}

source $TCA_SCRIPT_ROOT/utils.sh  # 加载工具的 shell 脚本;

TCA_IMAGE_NAME=${TCA_IMAGE_NAME:-"tencenttca/tca"}  # 设置镜像的名称
TCA_CONTAINER_NAME=${TCA_CONTAINER_NAME:-"tca-services"}  # 射中容器的名称
TCA_IMAGE_TAG=${TCA_IMAGE_TAG:-"latest"}  # 获取最新的版本;
TCA_IMAGE_BUILD=${TCA_IMAGE_BUILD:-"false"}  # 默认关闭 build 的命令;
TCA_INIT_DATA=${TCA_INIT_DATA:-"true"}  # 设置初始化数据的变量;

TCA_DOCKER_LOG_PATH=${TCA_LOG_PATH:-"$TCA_PROJECT_PATH/.docker_temp/logs/"}  # docker 日志的输出;
TCA_DOCKER_DATA_PATH=${TCA_DATA_PATH:-"$TCA_PROJECT_PATH/.docker_temp/data/"}
TCA_DOCKER_CONFIG_PATH=${TCA_CONFIG_PATH:-"$TCA_PROJECT_PATH/.docker_temp/configs/"}  # docker 的配置文件

# 根据docker images 的输出确定是否需要执行指定镜像的 docker build images
function build_image() {
    if [ "$(docker image inspect $TCA_IMAGE_NAME:$TCA_IMAGE_TAG 2>/dev/null)" == "[]" ]; then
        cd $TCA_PROJECT_PATH
        docker build -t $TCA_IMAGE_NAME:$TCA_IMAGE_TAG . || error_exit "Build image failed"
    fi
}

# 根据 build 的参数决定是否执行 build 的命令;
function get_image() {
    if [ "$TCA_IMAGE_BUILD" == "true" ]; then
        LOG_INFO "Build TCA Image: $TCA_IMAGE_NAME:$TCA_IMAGE_TAG"
        cd $TCA_PROJECT_PATH
        docker build -t $TCA_IMAGE_NAME:$TCA_IMAGE_TAG . || error_exit "Build image failed"
        return $?
    fi
    LOG_INFO "Pull TCA Image: $TCA_IMAGE_NAME:$TCA_IMAGE_TAG"
    docker pull $TCA_IMAGE_NAME:$TCA_IMAGE_TAG 2>/dev/null
    ret=$?
    if [ "$ret" != "0" ]; then
        build_image
    fi
}

# 部署单个的容器;
function deploy_container() {
    LOG_INFO "Deploy tca container command:"
    set -x
    docker run -it --ulimit nofile=10240:10240 --env TCA_INIT_DATA=$TCA_INIT_DATA \
        --name $TCA_CONTAINER_NAME --publish 80:80 --publish 8000:8000 --publish 9001:9001 \
        -v $TCA_DOCKER_LOG_PATH:/var/log/tca/ \
        -v $TCA_DOCKER_DATA_PATH:/var/opt/tca/ \
        -v $TCA_DOCKER_CONFIG_PATH:/etc/tca/ \
        $TCA_IMAGE_NAME:$TCA_IMAGE_TAG
    ret=$?

    set +x
    if [ "$ret" != "0" ]; then
        LOG_ERROR "Deploy tca docker failed"
    else
        LOG_INFO "TCA Docker Log Path:     $TCA_DOCKER_LOG_PATH"
        LOG_INFO "TCA Docker Data Path:    $TCA_DOCKER_DATA_PATH"
        LOG_INFO "TCA Docker Config Path:  $TCA_DOCKER_CONFIG_PATH"
    fi
}

# 启动这个容器;
function start_container() {
    LOG_INFO "Start tca container command:"
    set -x
    docker start $TCA_CONTAINER_NAME
    ret=$?
    set +x
    
    if [ "$ret" != "0" ]; then
        LOG_ERROR "Start tca docker failed"
    else
        LOG_INFO "TCA Docker Log Path:     $TCA_DOCKER_LOG_PATH"
        LOG_INFO "TCA Docker Data Path:    $TCA_DOCKER_DATA_PATH"
        LOG_INFO "TCA Docker Config Path:  $TCA_DOCKER_CONFIG_PATH"
    fi
}

# 按照变量停止的容器;
function stop_container() {
    LOG_INFO "Stop tca container command:"
    set -x
    docker stop $TCA_CONTAINER_NAME
    ret=$?
    set +x
    
    if [ "$ret" != "0" ]; then
        LOG_ERROR "Stop tca docker failed"
    else
        LOG_INFO "TCA Docker Log Path:     $TCA_DOCKER_LOG_PATH"
        LOG_INFO "TCA Docker Data Path:    $TCA_DOCKER_DATA_PATH"
        LOG_INFO "TCA Docker Config Path:  $TCA_DOCKER_CONFIG_PATH"
        LOG_WARN "Do not clear the above path unless it is necessary, otherwise it will affect TCA service."
        LOG_INFO "Stop tca docker successfully"
    fi
}

# docker 的部署的函数
function tca_docker_main() {
    command=$1
    case $command in
        deploy)
            LOG_INFO "Deploy tca container"
            get_image
            deploy_container
        ;;
        start)
            LOG_INFO "Start tca container"
            start_container
        ;;
        stop)
            LOG_INFO "Stop tca container"
            stop_container
        ;;
        *)
            LOG_ERROR "'$command' not support."
            exit 1
        ;;
    esac
}

