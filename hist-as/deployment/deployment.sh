#!/bin/bash

#
# NB! User writing this script doesn't know
#     what linux distribution it will run on!
#

#
# For Ubuntu distribution. Version 14.x or higher is assumed.
#

set -e
set -x

# URL of the root of the Riemann configuration.
# The following files are assumed under the URL:
#  riemann-ss-streams.clj - Riemann streams using SlipStream scale up/down actions,
#  dashboard.rb - Riemann dashboard configuration,
#  dashboard.json - Riemann dashboard layout and queries.
riemann_conf_url=`ss-get riemann_config_url`

# Scalability constraints provided by the user for his application.
scale_constraints_url=`ss-get scale_constraints_url`

hostname=`ss-get hostname`
ss_proxy_http_insecure=`ss-get ss_proxy_http_insecure`

cat /etc/*-release*

RIEMANN_VER_RHEL=0.2.11-1
RIEMANN_VER_DEB=0.2.11_all

SS_RUN_PROXY_VER=0.3
SS_PROXY_PORT=8008

SCALE_CONSTRAINTS_FILE=/etc/riemann/scale-constraints.edn

riemann_dashboard_port=

_configure_selinux() {
    [ -f /selinux/enforce ] && echo 0 > /selinux/enforce || true
    [ -f /etc/sysconfig/selinux ] && sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux || true
    [ -f /etc/selinux/config ] && sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config || true
}

_disable_ipv6() {
    cat > /etc/sysctl.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sudo sysctl -p
    cat /proc/sys/net/ipv6/conf/all/disable_ipv6
}

_wait_server_started() {
    set +e
    for i in {1..12}; do
        echo "$i .. sleeping 5 sec"
        sleep 5
        curl ${1}
        if [ $? -eq 0 ];then
            break
        fi
    done
    set -e
}

deploy_ntpd_rhel() {
    yum install -y ntp
    service ntpd start
    chkconfig ntpd on
}
deploy_ntpd_ubuntu() {
    apt-get update
    apt-get install -y ntp
    /etc/init.d/ntp start
    #chkconfig ntpd on
}

deploy_riemann_rhel() {
    yum localinstall -y \
        http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

    yum install -y ruby ruby-devel zlib-devel jre
    gem install --no-ri --no-rdoc riemann-client riemann-tools riemann-dash
    yum localinstall -y https://aphyr.com/riemann/riemann-${RIEMANN_VER_RHEL}.noarch.rpm
    chkconfig riemann on
    service riemann start
}
deploy_riemann_ubuntu() {

    # need Java 8 for promesa's java deps.
    add-apt-repository -y ppa:openjdk-r/ppa
    apt-get update -y
    apt-get install -y openjdk-8-jdk
    update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java

    # Ubuntu 14
    apt-get install -y ruby ruby-dev zlib1g-dev openjdk-7-jre build-essential

    # Fix for http://stackoverflow.com/questions/6784463/error-trustanchors-parameter-must-be-non-empty
    # on Ubuntu.
    sudo /var/lib/dpkg/info/ca-certificates-java.postinst configure

    # need Ruby ~> 2.0 for json
    apt-add-repository -y ppa:brightbox/ruby-ng
    apt-get update -y
    apt-get install -y ruby1.9

    gem install --no-ri --no-rdoc riemann-client riemann-tools riemann-dash

    curl -O https://aphyr.com/riemann/riemann_${RIEMANN_VER_DEB}.deb
    dpkg -i riemann_${RIEMANN_VER_DEB}.deb

    riemann_ss_conf=/etc/riemann/riemann-ss-streams.clj
    curl -sSf -o $riemann_ss_conf $riemann_conf_url/riemann-ss-streams.clj

    curl -sSf -o $SCALE_CONSTRAINTS_FILE $scale_constraints_url

    # Download SS Clojure client.
    proxy_lib_loc=/opt/slipstream/client/lib
    mkdir -p $proxy_lib_loc
    ss_run_proxy=$proxy_lib_loc/ss-run-proxy.jar
    ss_run_proxy_api=$proxy_lib_loc/ss-run-proxy-api.jar
    v=v$SS_RUN_PROXY_VER
    curl -k -sSfL -o ss-run-proxy-$v.tgz \
        https://github.com/slipstream/slipstream-auto-scale-apps/releases/download/$v/ss-run-proxy-$v.tgz
    tar -C $proxy_lib_loc -zxvf ss-run-proxy-$v.tgz

    # Start SS run proxy service.  TODO: need to chkconfig it!
    export SERVER_PORT=$SS_PROXY_PORT
    export HTTP_INSECURE=$ss_proxy_http_insecure
    java -jar $ss_run_proxy &
    echo "Waiting for SS run proxy to start."
    _wait_server_started http://localhost:$SERVER_PORT/can-scale
    # check SS run proxy is running.
    curl http://localhost:$SERVER_PORT/can-scale

    # Start Riemann.
    cat > /etc/default/riemann <<EOF
EXTRA_CLASSPATH=$ss_run_proxy_api
RIEMANN_CONFIG=$riemann_ss_conf
EOF
    /etc/init.d/riemann stop || true
    /etc/init.d/riemann start
}
_get_from_constraints_file() {
    awk '/'$1'/ {print $2}' $SCALE_CONSTRAINTS_FILE | tr -d '"'
}
start_riemann_dash() {
    cd /etc/riemann/
    wget $riemann_conf_url/dashboard.rb
    wget $riemann_conf_url/dashboard.json
    comp_name=$(_get_from_constraints_file :comp-name)
    service_metric=$(_get_from_constraints_file :service-metric)
    sed -i -e "s/<riemann-host>/$hostname/" /etc/riemann/dashboard.json
    sed -i -e "s/<comp-name>/$comp_name/g" /etc/riemann/dashboard.json
    sed -i -e "s/<service-metric>/$service_metric/g" /etc/riemann/dashboard.json
    riemann-dash dashboard.rb &
    riemann_dashboard_port=`awk '/port/ {print $3}' /etc/riemann/dashboard.rb`
}

deploy_graphite_ubuntu() {
    # Ubuntu 14
    DEBIAN_FRONTEND=noninteractive apt-get install -y graphite-web graphite-carbon apache2 libapache2-mod-wsgi
    #
    # Graphite
    rm -f /etc/apache2/sites-enabled/000-default.conf
    ln -s /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-enabled/
    python /usr/lib/python2.7/dist-packages/graphite/manage.py syncdb --noinput
    echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'email@example.com', 'password')" | \
        python /usr/lib/python2.7/dist-packages/graphite/manage.py shell
    chmod 755 /usr/share/graphite-web/graphite.wsgi
    chmod 666 /var/lib/graphite/graphite.db
    service apache2 restart
    #
    # Carbon cache
    sed -i -e 's/CARBON_CACHE_ENABLED=false/CARBON_CACHE_ENABLED=true/' /etc/default/graphite-carbon
    service carbon-cache start
}
deploy_graphite_rhel() {
    echo TODO
}

_configure_selinux
_disable_ipv6
ss-display "Deploying ntpd"
deploy_ntpd_ubuntu
#deploy_ntpd_rhel
# FIXME: disabled, as sometimes it takes too much time to deploy.
#ss-display "Deploying Graphite"
#deploy_graphite_ubuntu
#deploy_graphite_rhel
ss-display "Deploying Riemann"
deploy_riemann_ubuntu
#deploy_riemann_rhel
start_riemann_dash

service ufw stop
# Publish Riemann dashboard endpoint.
ss-set url.service "http://${hostname}:${riemann_dashboard_port}"

ss-display "Autoscaler is ready!"
ss-set ready true

exit 0

