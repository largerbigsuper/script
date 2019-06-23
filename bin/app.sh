#! /bin/bash

# ====================
#  自动部署脚本
# =====================

CMD=$0
ACTION=$1

USER_ROOT="/Users/turkey/Alibaba/"
APP="test"
APP_ROOT="/Users/turkey/Alibaba/$APP"
LOG_ROOT="$APP_ROOT/logs"
ENV_ROOT="$APP_ROOT/env"
BUILD_ROOT="$APP_ROOT/target"
APP_ZIP="$APP.tar.gz"
BUILD_FILE="$BUILD_ROOT/$APP_ZIP"
GIT_ROOT="$APP_ROOT/target/$APP"
APP_RUN_ROOT="$APP_ROOT/$APP"

APP_URL="https://github.com/largerbigsuper/test.git"
BRANCH="master"
REQUIREMENTS_FILE="$APP_RUN_ROOT/requirements.txt"
PIP_INDEX_URL="http://mirrors.aliyun.com/pypi/simple/"
PIP_TRUSTED_HOST="mirrors.aliyun.com"

# =====================
# source code manage
# =====================

mkdir -p $APP_ROOT
mkdir -p $LOG_ROOT
mkdir -p $BUILD_ROOT
mkdir -p $APP_RUN_ROOT

check_git() {
    if [ -d $GIT_ROOT ]; then
        echo "info: repository $APP ready!"
        cd $GIT_ROOT
        git checkout $BRANCH
        if [ $? -ne 0 ]; then
            git checkout -b $BRANCH
        fi
        # exit 0
        #git branch --set-upstream-to=origin/$BRANCH
    else
        echo "info: repository $APP does not exist, please clone first!"
        exit 1
    fi
}

git_clone() {

    if [ ! -d $GIT_ROOT ]; then
        git clone $APP_URL $GIT_ROOT

        if [ "$?" -eq 0 ]; then
            echo "info: clone $APP_URL successed."
        else
            echo "info: clonne $APP_URL failed!"
            exit 1
        fi
    fi
}

git_update() {
    check_git
    git pull origin $BRANCH:$BRANCH
}

# =====================
# python venv
# =====================

env_init() {
    if [ ! -d $ENV_ROOT ]; then
        echo "info: building env..."
        python3 -m venv $ENV_ROOT
        if [ $? -eq 0 ]; then
            echo "info: env ready."
        else
            echo "error: init env failed!"
            exit 1
        fi
    else
        echo "info env ready."
    fi

}

check_env() {
    if [ -d $ENV_ROOT ]; then
        echo "info: env ready."
        source $ENV_ROOT/bin/activate
    else
        env_init
        # echo "error: env not ready, please run '$SHELL $CMD env_init' first."
        # exit 1
    fi

}

check_requirements() {
    check_env
    if [ -f $REQUIREMENTS_FILE ]; then
        python3 -m pip install -r $REQUIREMENTS_FILE -i $PIP_INDEX_URL --trusted-host $PIP_TRUSTED_HOST --no-cache-dir
        if [ $? -ne 0 ]; then
            echo "error: failed requiremts filed!"
            exit 1
        else
            echo "info: install requiremts successed!"
        fi

    else
        echo "error: $REQUIREMENTS_FILE does not exist!"
        exit 1
    fi
}

# =====================
# build and backup
# =====================

app_backup() {
    echo $APP_RUN_ROOT
    if [ -d $APP_RUN_ROOT ]; then
        cd $APP_ROOT
        tar --exclude="$APP/*.pyc" -zcf "$APP.$(date +%Y%m%d%H%M%S).tar.gz" $APP
        if [ $? -eq 0 ]; then
            echo "info: backup ok."
        else
            echo "error: backup failed"
            exit 1
        fi
    fi
}

app_build() {
    check_git
    cd $BUILD_ROOT
    tar --exclude="$APP/.git" -zcf $APP_ZIP $APP
    if [ $? -eq 0 ]; then
        # mv $APP_ZIP  $APP_ROOT
        echo "info: build successed."
    else
        echo "error: build failed!"
        exit 1
    fi
}

check_build() {
    if [ ! -f $BUILD_FILE ]; then
        echo "error: build first."
        exit 1
    fi

}

app_upzip() {
    # app_build
    local zipfile=$1
    cd $BUILD_ROOT
    if [ ! -f "$BUILD_ROOT/$zipfile" ]; then
        echo "error: $zipfile does not exist"
        exit 1
    fi
    app_backup
    tar -zxf "$BUILD_ROOT/$zipfile" -C $APP_ROOT
    if [ $? -eq 0 ]; then
        echo "info: compress $zipfile successed."
    else
        echo "error: compress $zipfie failed."
    fi

}

check_supervisord_status() {
    if [ -f "$LOG_ROOT/supervisord.pid" ]; then
        echo "info: supervisord is running"
    else
        supervisord -c "$APP_RUN_ROOT/supervisord.conf"
        if [ $? -eq 0 ]; then
            echo "info: supervisord is running"
        else
            echo "error: supervisord is not running"
            exit 1
        fi
    fi
}

start() {

    check_supervisord_status
    supervisorctl -c "$APP_RUN_ROOT/supervisord.conf" restart all
    if [ $? -eq 0 ]; then
        echo "info: start $APP ok"
    else
        echo "error: start $APP failed"
        exit 1
    fi

}

stop() {
    check_supervisord_status
    supervisorctl -c "$APP_RUN_ROOT/supervisord.conf" stop all
    if [ $? -eq 0 ]; then
        echo "info: stop $APP ok"
    else
        echo "error: stop $APP failed"
        exit 1
    fi

}

app_install() {
    git_clone || exit
    git_update || exit
    app_build || exit
    app_upzip $APP_ZIP || exit
    check_env || exit
    check_requirements || exit
    start || exit
}

# =====================
# app server manage
# =====================

case $ACTION in
git_clone)
    git_clone
    ;;

git_update)
    git_update
    ;;
env_init)
    env_init
    ;;
check_requirements)
    check_requirements
    ;;
app_build)
    app_build
    ;;
app_upzip)
    app_upzip $APP_ZIP
    ;;

start)
    start
    ;;

stop)
    stop
    ;;
app_install)
    app_install
    ;;

esac
