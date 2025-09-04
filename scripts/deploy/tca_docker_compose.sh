#!/bin/bash

CURRENT_SCRIPT_PATH=$( cd "$(dirname ${BASH_SOURCE[0]})"; pwd )  # 定义当前的绝对路径;
export TCA_SCRIPT_ROOT=${TCA_SCRIPT_ROOT:-"$( cd $(dirname $CURRENT_SCRIPT_PATH); pwd )"}
export TCA_PROJECT_PATH=${TCA_PROJECT_PATH:-"$( cd $(dirname $TCA_SCRIPT_ROOT); pwd )"}

source $TCA_SCRIPT_ROOT/utils.sh
source $TCA_SCRIPT_ROOT/server/_base.sh  # 导入定义的路径,以及部署的过程中输出的配置文件;

CODEDOG_DBUSER=${CODEDOG_DBUSER:-root}  # 设置默认值; 设置用户名与密码;
CODEDOG_DBPASSWD=${CODEDOG_DBPASSWD:-'TCA!@#2021'}

# 打印介绍;
function tca_introduction() {
    LOG_INFO "===========================================================" 
    LOG_INFO "                  _______    _____                         "
    LOG_INFO "                 |__   __|  / ____|     /\                 "   
    LOG_INFO "                    | |    | |         /  \                "  
    LOG_INFO "                    | |    | |        / /\ \               "  
    LOG_INFO "                    | |    | |____   / ____ \              "
    LOG_INFO "                    |_|     \_____| /_/    \_\             "
    LOG_INFO "                                                           "         
    LOG_INFO "==========================================================="
    LOG_INFO "| docker-compose 部署说明                                  |"
    LOG_INFO "| 默认部署以下服务                                           |"
    LOG_INFO "| - mysql, redis, nginx                                   |"
    LOG_INFO "| - main-server, main-worker, main-beat                   |"
    LOG_INFO "| - analysis-server, analysis-worker                      |"
    LOG_INFO "| - scmproxy                                              |"
    LOG_INFO "| - login-server                                          |"
    LOG_INFO "| - file-server, file-nginx                               |"
    LOG_INFO "|                                                         |"
    LOG_INFO "| 数据缓存路径                                              |"
    LOG_INFO "| - mysql数据：./.docker_data/mysql                        |"
    LOG_INFO "| - redis数据：./.docker_data/redis                        |"
    LOG_INFO "| - 本地文件数据：./.docker_data/filedata                   |"
    LOG_INFO "|                                                         |"
    LOG_INFO "| 日志缓存路径                                              |"
    LOG_INFO "| - main-server：./.docker_data/logs/main_server/         |"
    LOG_INFO "| - main-worker：./.docker_data/logs/main_worker/         |"
    LOG_INFO "| - main-beat：/.docker_data/logs/main_beat/              |"
    LOG_INFO "| - analysis-server：./.docker_data/logs/analysis_server/ |"
    LOG_INFO "| - analysis-worker：./.docker_data/logs/analysis_worker/ |"
    LOG_INFO "| - scmproxy: ./.docker_data/logs/scmproxy/               |"
    LOG_INFO "| - file-server: ./.docker_data/logs/file-server/         |"
    LOG_INFO "| - file-nginx: ./.docker_data/logs/file-nginx/           |"
    LOG_INFO "| - login-server: ./.docker_data/logs/login-server/       |"
    LOG_INFO "|                                                         |"
    LOG_INFO "==========================================================="
    LOG_INFO "部署文档：https://tencent.github.io/CodeAnalysis/zh/quickStarted/deploySever.html"
    LOG_INFO "Q&A文档：https://tencent.github.io/CodeAnalysis/zh/quickStarted/FAQ.html"
    LOG_INFO ""
}

# 根据架构决定当前选择的镜像
function set_image_with_arch() {
    system_os=$( uname )
    if [ $system_os == "Darwin" ]; then
        sed_command="sed -i.bak -E"
    else
        sed_command="sed -ir -E"
    fi
    current_arch=$( uname -m )
    if [ $current_arch == "aarch64" ] || [ $current_arch == "arm64" ]; then
        $sed_command 's/^([[:space:]]*)(image: mysql)/\1\# \2/' $TCA_PROJECT_PATH/docker-compose.yml
        $sed_command 's/^([[:space:]]*)\#[[:space:]]*(image: mariadb:10)/\1\2/' $TCA_PROJECT_PATH/docker-compose.yml
    else
        $sed_command 's/^([[:space:]]*)\#[[:space:]]*(image: mysql:5)/\1\2/' $TCA_PROJECT_PATH/docker-compose.yml
        $sed_command 's/^([[:space:]]*)[[:space:]]*(image: mariadb:10)/\1\# \2/' $TCA_PROJECT_PATH/docker-compose.yml
    fi
}

# 强制重新常见 mysql 与 redis
function start_db() {
    docker-compose up --force-recreate -d mysql redis
}

# 初始化的数据库的数据;
function init_db() {
    db_container=$(docker-compose ps | grep mysql | awk '{print $1}')
    # 执行挂载进去的 sql 文件进行操作, 进行了创建数据库的操作, 但是没有建表与建立用户;
   docker-compose exec mysql /bin/bash -c \
        "printf 'wait db [DB default password: TCA!@#2021]\n'; \
         until \$(MYSQL_PWD=${CODEDOG_DBPASSWD} mysql -u${CODEDOG_DBUSER} -e '\s' > /dev/null 2>&1); do \
            printf '.' && sleep 1; \
         done; echo
        "
}

# 文件服务器初始化
function init_file() {
    mkdir -p $CURRENT_PATH/server/projects/file
    docker-compose up -d file-server 
    docker-compose exec file-server bash -c \
        "python manage.py migrate --noinput --traceback"
}

# 登陆服务器初始化
function init_login() {
    mkdir -p $CURRENT_PATH/server/projects/login
    docker-compose up -d login-server
    # 启动服务之后, 在容器内部进行数据初始化的操作;
    docker-compose exec login-server bash -c \
        "python manage.py migrate --noinput --traceback; \
         python manage.py createcachetable; \
         python manage.py initializedb;
        "
}

# Main服务器初始化
function init_main() {
    mkdir -p $CURRENT_PATH/server/projects/main/log
    docker-compose up -d main-server
    docker-compose exec main-server /bin/bash -c \
        "python manage.py migrate --noinput --traceback; \
         python manage.py createcachetable; \
         python manage.py initializedb_open; \
         python manage.py initialize_exclude_paths; \
         python manage.py loadlibs all --dirname open_source_toollib --ignore-auth; \
         python manage.py loadcheckers all --dirname open_source; \
         python manage.py loadpackages all --dirname open_source_package;
        "
}

# Analysis服务器初始化
function init_analysis() {
    mkdir -p $CURRENT_PATH/server/projects/analysis/log
    docker-compose up -d analysis-server
    # 在 django 中执行处理好的服务信息;
    docker-compose exec analysis-server /bin/bash -c \
        "python manage.py migrate --noinput --traceback; \
         python manage.py createcachetable; \
         python manage.py initialuser; \
        "
}
# 启动所有的服务;
function start_all_services() {
    docker-compose up -d  # 对于处于运行状态的容器,没有修改配置的话, 会保持当前运行状态
}

# 停止全部的服务;
function stop_all_services() {
    docker-compose stop
}

# 部署全部的服务,
function deploy_all_services() {
    cd $TCA_PROJECT_PATH
    set_image_with_arch
    # 如果函数执行失败, 则执行 error_exit 并打印参数的信息;

    # 1. 启动系统级的依赖中间件, MYSQL Redis
    start_db || error_exit "start db failed"
    # 2. 启动需要进行数据初始化的服务;
    init_db || error_exit "init db failed"
    init_file || error_exit "init file server failed"
    init_login || error_exit "init login server failed"
    init_analysis || error_exit "init analysis server failed"
    init_main || error_exit "init main server failed"
    # 启动所有的服务;
    start_all_services  # 由于docker-compose.yml 的文件没有发生变化;
    tca_introduction  # 打印 docker-compose 部署方式的需要的介绍;
}

# 获取命令行的参数
function tca_docker_compose_main() {
    command=$1  # 获取命令行的参数;
    case $command in
        deploy)
            LOG_INFO "Deploy tca docker-compose"
            deploy_all_services  # 部署全部的服务, 先启动中间件 + 初始化 + 启动全部服务;
        ;;
        start)
            LOG_INFO "Start tca docker-compose"
            start_all_services  # 直接启动全部服务
        ;;
        stop)
            LOG_INFO "Stop tca docker-compose"
            stop_all_services  # 停止全部服务;
        ;;
        build)
            LOG_INFO "Build tca image"  # 构建镜像的操作;
            docker-compose build main-server analysis-server file-server login-server scmproxy client
        ;;
        *)
            # 其他的命令参数, 不支持启动;
            LOG_ERROR "'$command' not support."
            exit 1
    esac
}

