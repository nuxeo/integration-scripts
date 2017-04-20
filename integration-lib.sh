#!/bin/bash
###
# Lib to ease CI scripts

HERE=$(cd $(dirname $0); pwd -P)
SOURCE_DIR=$(cd $(dirname $BASH_SOURCE[0]); pwd -P)
JVM_XMX=${JVM_XMX:-1g}
NXVERSION=${NXVERSION:-master}
NXTAG=${NXTAG:-}
NXDISTRIBUTION="$HERE/nuxeo-$NXVERSION/nuxeo-distribution"
JBOSS_HOME="$HERE/jboss"
TOMCAT_HOME="$HERE/tomcat"
JETTY_HOME="$HERE/jetty"
SERVER=${SERVER:-jboss}
DELAYED=${DELAYED:-0}

if [ "$SERVER" = "tomcat" ]; then
    SERVER_HOME="$TOMCAT_HOME"
    TOMCAT_LIB="$TOMCAT_HOME/lib"
    SERVER_LIB="$TOMCAT_LIB"
elif [ "$SERVER" = "jetty" ]; then
    SERVER_HOME="$JETTY_HOME"
    JETTY_LIB="$JETTY_HOME/lib"
    SERVER_LIB="$JETTY_LIB"
elif [ "$SERVER" = "jboss" ]; then
    SERVER_HOME="$JBOSS_HOME"
    JBOSS_LIB="$JBOSS_HOME/server/default/lib"
    SERVER_LIB="$JBOSS_LIB"
else
    die "ERROR: unknown server! Please set SERVER"
fi

# include dblib
. $SOURCE_DIR/integration-dblib.sh

get_templates_list() {
    if [ -z "$NUXEO_CONF" ]; then
        echo "[ERROR] NUXEO_CONF must be set"
        exit 1
    fi
    templates=$(grep -E "^#?nuxeo.templates=" $NUXEO_CONF | perl -p -e "s/^#?nuxeo.templates=//" | tr "," " ")
}

activate_db_template() {
    if [ -z "$NUXEO_CONF" ]; then
        echo "[ERROR] NUXEO_CONF must be set"
        exit 1
    fi
    db=${1:-"default"}
    get_templates_list
    newtemplates=""
    for t in $templates; do
        if [ "$t" = "default" ]; then
            t=$db
        fi
        if [ ! -z $newtemplates ]; then
            newtemplates+=","
        fi
        newtemplates+="$t"
    done
    perl -p -i -e "s/^#?nuxeo.templates=.*$/nuxeo.templates=$newtemplates/g" $NUXEO_CONF
}

activate_template() {
    if [ -z "$NUXEO_CONF" ]; then
        echo "[ERROR] NUXEO_CONF must be set"
        exit 1
    fi
    tpl=${1:-""}
    if [ -z "$tpl" ]; then
        echo "[ERROR] No template name specified"
        exit 1
    fi
    get_templates_list
    newtemplates=""
    tpl_already_exists=false
    for t in $templates; do
        if [ "$t" = "$tpl" ]; then
            tpl_already_exists=true
        fi
        if [ ! -z $newtemplates ]; then
            newtemplates+=","
        fi
        newtemplates+="$t"
    done
    if [ "$tpl_already_exists" = "false" ]; then
        if [ ! -z $newtemplates ]; then
            newtemplates+=","
        fi
        newtemplates+="$tpl"
    fi
    perl -p -i -e "s/^#?nuxeo.templates=.*$/nuxeo.templates=$newtemplates/g" $NUXEO_CONF
}

set_key_value() {
    if [ -z "$NUXEO_CONF" ]; then
        echo "[ERROR] NUXEO_CONF must be set"
        exit 1
    fi
    if [ "$#" != "2" ]; then
        echo "[ERROR] Usage: set_key_value key value"
        exit 1
    fi
    key=$1
    value=$2
    has_key=$(grep -E "^#?$key=" $NUXEO_CONF | wc -l)
    if [ "$has_key" = "0" ]; then
        echo "$key=$value" >> $NUXEO_CONF
    else
        perl -p -i -e "s,^#?$key=.*$,$key=$value,g" $NUXEO_CONF
    fi
}

check_ports_and_kill_ghost_process() {
    hostname=${1:-0.0.0.0}
    ports=${2:-8080 14440}
    for port in $ports; do
      RUNNING_PID=`lsof -n -i TCP@$hostname:$port | grep '(LISTEN)' | awk '{print $2}'`
      if [ ! -z $RUNNING_PID ]; then
          echo [WARN] A process is already using port $port: $RUNNING_PID
          echo [WARN] Storing jstack in $PWD/$RUNNING_PID.jstack then killing process
          [ -e /usr/lib/jvm/java-6-sun/bin/jstack ] && /usr/lib/jvm/java-6-sun/bin/jstack $RUNNING_PID >$PWD/$RUNNING_PID.jstack
          kill $RUNNING_PID || true
          sleep 5
          kill -9 $RUNNING_PID || true
      fi
    done
}

# IT tests should not call that function, but download sources to be tested
update_distribution_source() {
    if [ ! -d "$NXDISTRIBUTION" ]; then
        mkdir -p `dirname "$NXDISTRIBUTION"`
        git clone git@github.com:nuxeo/nuxeo-distribution.git "$NXDISTRIBUTION" || exit 1
    fi
    (cd "$NXDISTRIBUTION" && git checkout master && git fetch --tags && git pull --all&& git checkout $NXVERSION) || exit 1
    if [ ! -z $NXTAG ]; then
        (cd "$NXDISTRIBUTION" && git checkout $NXTAG) || exit 1
    fi
}

build_jboss() {
    (cd "$NXDISTRIBUTION" && mvn clean install -Pnuxeo-dm,cmis,jboss,nuxeo-dm-jboss) || exit 1
}

build_jboss_ep() {
    echo "DEPRECATED - Use Nuxeo CAP instead of EP"
}

build_cap() {
    (cd "$NXDISTRIBUTION" && mvn install -Pnuxeo-cap,$SERVER) || exit 1
}

set_jboss_log4j_level() {
    JBOSS=$1
    shift
    LEVEL=$1
    shift
    sed -i "/<root>/,/root>/ s,<level value=.*\$,<level value=\"$LEVEL\"/>," "$JBOSS"/server/default/conf/jboss-log4j.xml
}

setup_server_conf() {
    SERVER_HOME=${1:-"$SERVER_HOME"}
    MAIL_FROM=${MAIL_FROM:-`dirname $PWD|xargs basename`\@$HOSTNAME}
    JMX_PORT=${JMX_PORT:-1089}
    NUXEO_CONF="$SERVER_HOME"/bin/nuxeo.conf
    activate_template monitor
    set_key_value nuxeo.bind.address $IP
    set_key_value nuxeo.loopback.url http://$IP:8080/nuxeo
    set_key_value mail.transport.host merguez.in.nuxeo.com
    set_key_value mail.transport.port 2500
    set_key_value mail.from $MAIL_FROM
    # Workaround for broken jps in Java 6u24
    # http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=7021676
    # http://www.linuxweblog.com/jps-jstat-tomcat
    set_key_value launcher.override.java.tmpdir false
    set_key_value nuxeo.wizard.done true
    [ ! -z $NX_JAVA_HOME ] &&  set_key_value JAVA_HOME $NX_JAVA_HOME
    cat >> "$NUXEO_CONF" <<EOF || exit 1
JAVA_OPTS=-server -Xms$JVM_XMX -Xmx$JVM_XMX -XX:MaxPermSize=512m \
-Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 \
-Xloggc:\${nuxeo.log.dir}/gc.log  -verbose:gc -XX:+PrintGCDetails \
-XX:+PrintGCTimeStamps \
-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false
EOF
    chmod u+x "$SERVER_HOME"/bin/*.sh "$SERVER_HOME"/bin/*ctl 2>/dev/null

    if [ "$SERVER" = jboss ]; then
        set_jboss_log4j_level $SERVER_HOME INFO
        echo "org.nuxeo.systemlog.token=dolog" > "$SERVER_HOME"/templates/common/config/selenium.properties
        if [ -f "$SERVER_HOME"/server/default/data/NXRuntime/data/installAfterRestart-DM.log ]; then
            cp "$SERVER_HOME"/server/default/data/NXRuntime/data/installAfterRestart-DM.log "$SERVER_HOME"/server/default/data/NXRuntime/data/installAfterRestart.log
        fi
        mkdir -p "$SERVER_HOME"/log
    fi
    if [ "$SERVER" = tomcat ]; then
        echo "org.nuxeo.systemlog.token=dolog" > "$SERVER_HOME"/templates/common/config/selenium.properties
        cp "$SERVER_HOME"/nxserver/data/installAfterRestart-DM.log "$SERVER_HOME"/nxserver/data/installAfterRestart.log
    fi
}

setup_jboss() {
    if [ $# == 2 ]; then
        JBOSS="$1"
        shift
    else
        JBOSS="$JBOSS_HOME"
    fi
    IP=${1:-0.0.0.0}
    if [ ! -d "$JBOSS" ] || [ ! -z $NEW_JBOSS ] ; then
        [ -d "$JBOSS" ] && rm -rf "$JBOSS"
        cp -r "$NXDISTRIBUTION"/nuxeo-distribution-jboss/target/nuxeo-*-jboss "$JBOSS" || exit 1
    else
        echo "Using previously installed JBoss. Set NEW_JBOSS variable to force new JBOSS deployment"
        if [ -f "$SERVER_HOME"/server/default/data/NXRuntime/data/installAfterRestart-DM.log ]; then
            mkdir -p saved_files
            mv "$JBOSS"/server/default/data/NXRuntime/data/installAfterRestart* saved_files/
            rm -rf "$JBOSS"/server/default/data/* "$JBOSS"/log/*
            mkdir -p "$JBOSS"/server/default/data/NXRuntime/data
            mv saved_files/* "$JBOSS"/server/default/data/NXRuntime/data/
            rmdir saved_files
        fi
    fi
    mkdir -p "$JBOSS"/log
    setup_server_conf $JBOSS
}

build_tomcat() {
    (cd "$NXDISTRIBUTION" && mvn clean install -Pnuxeo-dm,tomcat) || exit 1
}

setup_tomcat() {
    if [ $# == 2 ]; then
        TOMCAT="$1"
        shift
    else
        TOMCAT="$TOMCAT_HOME"
    fi
    IP=${1:-0.0.0.0}
    if [ ! -d "$TOMCAT" ] || [ ! -z $NEW_TOMCAT ] ; then
        [ -d "$TOMCAT" ] && rm -rf "$TOMCAT"
        unzip "$NXDISTRIBUTION"/nuxeo-distribution-tomcat/target/nuxeo-distribution-tomcat-*nuxeo-cap.zip -d /tmp/ \
        && mv /tmp/nuxeo-cap-*-tomcat "$TOMCAT" || exit 1
    else
        echo "Using previously installed Tomcat. Set NEW_TOMCAT variable to force new TOMCAT deployment"
        rm -rf "$TOMCAT"/webapps/nuxeo/nxserver/data/* "$TOMCAT"/log/*
    fi
    setup_server_conf $TOMCAT
}

deploy_ear() {
  JBOSS=${1:-$JBOSS_HOME}
  if [ ! -d "$JBOSS"/server/default/deploy/nuxeo.ear ] || [ -z $NEW_JBOSS ] ; then
    deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-distribution-jboss/target/nuxeo-dm-jboss/server/default/deploy/nuxeo.ear "$JBOSS"/server/default/deploy/nuxeo.ear
  else
    echo "Using EAR already present in JBoss assuming it's a fresh build."
  fi
}

deploySRCtoDST() {
  SRC=$1
  DST=$2
  [ -d "$DST" ] && rm -rf "$DST"
  cp -r $SRC $DST
}

start_server() {
    if [ $# == 2 ]; then
        SERVER_HOME="$1"
        shift
    fi
    IP=${1:-0.0.0.0}
    check_ports_and_kill_ghost_process $IP
    "$SERVER_HOME"/bin/nuxeoctl start || exit 1
    sleep $DELAYED
    if [ -z "$SKIP_MONITORING" ]; then
        if [ ! -z "$MONITOR_THREAD_CONTENTION" ]; then
            "$SERVER_HOME"/bin/monitorctl.sh enable-cm
        fi
        "$SERVER_HOME"/bin/monitorctl.sh start
    fi
}

stop_server() {
    SERVER_HOME=${1:-"$SERVER_HOME"}
    if [ -z "$SKIP_MONITORING" ]; then
        "$SERVER_HOME"/bin/monitorctl.sh stop
    fi
    "$SERVER_HOME"/bin/nuxeoctl stop
    if [ -z "$SKIP_MONITORING" ]; then
        if [ ! -z $PGPASSWORD ]; then
            "$SERVER_HOME"/bin/monitorctl.sh vacuumdb
        fi
    fi
    echo "### 10 most frequent errors --------------"
    grep " ERROR \[" "$SERVER_HOME"/log/server.log | sed "s/^.\{24\}//g" | sort | uniq -c | sort -nr | head
    echo "### 10 first errors ----------------------"
    grep -nm 10 " ERROR " "$SERVER_HOME"/log/server.log
    echo "### --------------------------------------"
    gzip "$SERVER_HOME"/log/*.log
    gzip -cd  "$SERVER_HOME"/log/server.log.gz 2>/dev/null > "$SERVER_HOME"/log/server.log
}

# Downloads a file and retries x times after a wait period of y seconds (in case of failure)
#
# It does not overwrite a file if it already exists (return code 3)
# It does not resume download in case of failure but rather restarts it
#
# DOWNLOAD_URL the url of the file to download [MANDATORY]
# RETRY_COUNTER number of retries (minimum 1, default is 5 times) [OPTIONAL]
# RETRY_DELAY time to wait before retrying (minimum 1, default is 3 seconds) [OPTIONAL]
#
# examples:
#   downloadWithRetry "http://community.nuxeo.com/static/releases/nuxeo-5.3.1/nuxeo-shell-5.3.1.zip" 4 2
#   downloadWithRetry "http://community.nuxeo.com/static/releases/nuxeo-8.10/nuxeo-8.10-vm-vbox.zip"
#   downloadWithRetry "http://community.nuxeo.com/static/releases/nuxeo-5.3.1/nuxeo-shell-5.3.1.zip" "" 2
#   downloadWithRetry "http://community.nuxeo.com/static/releases/nuxeo-5.3.1/nuxeo-shell-5.3.1.zip.md5" 7
downloadWithRetry() {
    local DOWNLOAD_URL=$1
    local RETRY_COUNTER=${2:-5}
    local RETRY_DELAY=${3:-3}
    local DOWNLOAD_FILENAME=${DOWNLOAD_URL##*/} # last part of a url

    [[ $RETRY_COUNTER =~ ^[1-9][0-9]*$ ]] || RETRY_COUNTER=5 # if counter not > 0 then default value
    [[ $RETRY_DELAY =~ ^[1-9][0-9]*$ ]] || RETRY_DELAY=3 # if delay is not > 0 then default value

    if [ -f "$DOWNLOAD_FILENAME" ]; then
        echo "ERROR: $DOWNLOAD_FILENAME already exists."
        return 3
    fi

    until [ $RETRY_COUNTER -lt 1 ]; do
        local CURL_ERR=0
        local CURL_HTTP_RES=0
        CURL_HTTP_RES=$(curl -ns -w "%{http_code}" -o "$DOWNLOAD_FILENAME" -C - "$DOWNLOAD_URL") || CURL_ERR=$?
        if [ "$CURL_ERR" -eq 0 ] && [ "$CURL_HTTP_RES" -eq 200 ]; then
            return 0
        fi
        echo "FAILED: could not retrieve $DOWNLOAD_FILENAME, HTTP code is $CURL_HTTP_RES, RETURN code is $CURL_ERR"
        rm -f "$DOWNLOAD_FILENAME"
        RETRY_COUNTER=$((RETRY_COUNTER - 1))
        sleep $RETRY_DELAY
    done
    echo "ERROR: could not retrieve $DOWNLOAD_URL"
    return 1
}
