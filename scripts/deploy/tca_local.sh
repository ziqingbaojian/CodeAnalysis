#!/bin/bash
# 启动 TCA Web 与 Server服务

# 获取路径,
CURRENT_SCRIPT_PATH=$( cd "$(dirname ${BASH_SOURCE[0]})"; pwd )
export TCA_SCRIPT_ROOT=${TCA_SCRIPT_ROOT:-"$( cd $(dirname $CURRENT_SCRIPT_PATH); pwd )"}

# 加载依赖的 shell 脚本文件;
source $TCA_SCRIPT_ROOT/utils.sh  # 导入开源的
source $TCA_SCRIPT_ROOT/config.sh  # 系统启动需要的环境变量
source $TCA_SCRIPT_ROOT/base/install_python.sh  # 安装 Python3.7
source $TCA_SCRIPT_ROOT/base/install_db.sh  # 安装 redis, mysql
source $TCA_SCRIPT_ROOT/base/install_nginx.sh  # 安装 Nginx
source $TCA_SCRIPT_ROOT/server/init_config.sh  # 初始化配置, 处理开源上没有的私有配置文件, 以及缺少的日志目录, 移动 Nginx 的配置文件;
source $TCA_SCRIPT_ROOT/server/init_data.sh  # 检查 mysql 的命令, 并且初始化数据;
source $TCA_SCRIPT_ROOT/web/init.sh  # 部署前端需要的 nginx 文件;
source $TCA_SCRIPT_ROOT/server/start.sh
source $TCA_SCRIPT_ROOT/server/stop.sh  # 停止服务;
source $TCA_SCRIPT_ROOT/server/healthcheck.sh  # 健康检查的脚本;
source $TCA_SCRIPT_ROOT/client/init.sh  # 初始化客户端
source $TCA_SCRIPT_ROOT/client/check.sh  # 检查启动
source $TCA_SCRIPT_ROOT/client/start.sh   # 启动
source $TCA_SCRIPT_ROOT/client/stop.sh  # 停止终端客户端;


# 安装服务启动的依赖,
function tca_local_install() {
    service=$1
    case $service in
        base)
            # 安装系统中间件;
            LOG_INFO "Install base software: Python3.7, Redis, Mariadb(or MySQL), Nginx"
            interactive_install_python
            interactive_install_redis
            interactive_install_mariadb
            interactive_install_nginx
        ;;
        server)
           # 初始化配置以及初始化数据
            LOG_INFO "Init tca server config"
            init_server_config
            init_server_db_and_data
        ;;
        web)
            LOG_INFO "Init tca web config"
            init_web_config
        ;;
        client)
            LOG_INFO "Init tca client config"
            init_client_config
        ;;
        tca)
            # 加载配置与输出
            LOG_INFO "Init tca server config"
            init_server_config
            init_server_db_and_data
            LOG_INFO "Init tca web config"
            init_web_config
            LOG_INFO "Init tca client config"
            init_client_config
        ;;
        *)
            # 交互式安装 python redis 以及其他的服务, 加载配置;
            LOG_INFO "1. Install base software: Python, Redis, Mariadb(or MySQL), Nginx"
            interactive_install_python
            interactive_install_redis
            interactive_install_mariadb
            interactive_install_nginx

            LOG_INFO "2. Init tca server config"
            init_server_config
            init_server_db_and_data

            LOG_INFO "3. Init tca web config"
            init_web_config

            LOG_INFO "4. Init tca client config"
            init_client_config
        ;;
    esac
}

# 启动指定的服务
function tca_local_start() {
    LOG_INFO "start tca server"
    service=$1
    case "$service" in
        mysql)
            restart_mariadb
        ;;
        mariadb)
            restart_mariadb
        ;;
        redis)
            restart_redis
        ;;
        main)
            restart_main
        ;;
        analysis)
            restart_analysis
        ;;
        file)
            restart_file
        ;;
        login)
            restart_login
        ;;
        scmproxy)
            restart_scmproxy
        ;;
        nginx)
            start_nginx
        ;;
        client)
            start_client
        ;;
        *)
            start_tca_server  # 启动全部的服务, server/start.sh
            start_client
        ;;
    esac
}

# 停止指定的目录;
function tca_local_stop() {
    service=$1
    case "$service" in
        main)
            stop_main_server
            stop_main_worker
        ;;
        analysis)
            stop_analysis_server
            stop_analysis_worker
        ;;
        file)
            stop_file_server
        ;;
        login)
            stop_login_server
        ;;
        scmproxy)
            stop_scmproxy_server
        ;;
        nginx)
            stop_nginx
        ;;
        client)
            stop_client
        ;;
        *)
            stop_tca_server  # 停止全部的服务;
            stop_client
        ;;
    esac
}

# 打印帮助的信息;
function tca_local_help() {
    LOG_INFO "format: ./quick_install.sh local command"
    LOG_INFO "example: ./quick_install.sh local deploy"
    LOG_INFO "Support command:"
    LOG_INFO "1. deploy : install base sofeware(Python/MySQL/Redis/Nginx), init tca server&web and start all service status"
    LOG_INFO "2. install: install base sofeware(Python/MySQL/Redis/Nginx) and init tca server&web"
    LOG_INFO "3. start  : start service, params: mysql/redis/main/analysis/file/login/scmproxy/nginx/all"
    LOG_INFO "4. stop   : stop service, params: main/analysis/file/login/scmproxy/nginx/all"
    LOG_INFO "5. check  : check all serivces status."
    LOG_INFO "6. log    : print all serivces log path."
    LOG_INFO "7. help   : print script document."
}

# 接收命令以及参数, 完成分发的具体执行;
function tca_local_main() {
    pre_check
    command=$1
    service=$2
    # command: install start stop check log help
    case "$command" in
        deploy)
            tca_local_install
            tca_local_start
            sleep 2
            check_tca_local_status
            check_tca_client_status
        ;;
        install)
            tca_local_install $service
        ;;
        start)
            tca_local_start $service
        ;;
        stop)
            tca_local_stop $service
        ;;
        check)
            check_tca_local_status
            check_tca_client_status
        ;;
        log)
            get_tca_local_log
        ;;
        help)
            LOG_INFO "TCA Local Script Help"
            tca_local_help
        ;;
        *)
            LOG_WARN "Command:'$command' not supported. [Support command: deploy/install/start/stop/check/log/help]"
            tca_local_help
            exit 1
        ;;
    esac
}

