#!/usr/bin/env bash

set -eufx -o pipefail

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

deploy_java_ubuntu() {
    add-apt-repository -y ppa:openjdk-r/ppa
    apt-get update -y
    apt-get install -y openjdk-8-jdk
    update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java
}

deploy_python_ubuntu() {
    apt-get update -y
    apt-get install -y python
}

deploy_condor_ubuntu() {
    cm_hostname=$HOSTNAME
    var="127.0.0.1 $cm_hostname localhost"
    sed -i "1s/.*/$var/" /etc/hosts
    hostnamectl set-hostname $cm_hostname
    export DEBIAN_FRONTEND=noninteractive
    add-apt-repository 'deb http://research.cs.wisc.edu/htcondor/ubuntu/development/ trusty contrib'
    wget -qO - http://research.cs.wisc.edu/htcondor/ubuntu/HTCondor-Release.gpg.key | sudo apt-key add -
    apt-get update -q
    apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" condor
    mkdir -p /local/condor/home
    chown condor:condor /local/condor -R
    #echo "LOCAL_DIR = /local/condor/home" >> /etc/condor/condor_config.local
    cat >> /etc/condor/condor_config.local <<EOF
CONDOR_HOST = \$(HOSTNAME)
COLLECTOR_HOST = \$(CONDOR_HOST)
ALLOW_WRITE = *
ALLOW_READ = *
ALLOW_DAEMON = *
ALLOW_NEGOTIATOR = *
ALLOW_NEGOTIATOR_SCHEDD = *
ALLOW_ADMINISTRATOR = *
ALLOW_OWNER = *
DAEMON_LIST = MASTER, STARTD
DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR, SCHEDD
QUEUE_SUPER_USERS = root, condor
SEC_DEFAULT_AUTHENTICATION = NEVER
SEC_DEFAULT_NEGOTIATION = NEVER
EOF
    ss-set cm.hostname $cm_hostname
    eth0_ip=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
    ss-set cm.ip $eth0_ip
    service condor restart
    ss-display "HTCondor Central Manager is ready"
    ss-set cm.ready true
}

deploy_pegasus() {
    wget -O - http://download.pegasus.isi.edu/pegasus/gpg.txt | sudo apt-key add -
    echo 'deb [arch=amd64] http://download.pegasus.isi.edu/pegasus/ubuntu trusty main' | sudo tee /etc/apt/sources.list.d/pegasus.list
    apt-get update -q
    apt-get install pegasus -y
    export PYTHONPATH=`pegasus-config --python`
    export PERL5LIB=`pegasus-config --perl`
    export CLASSPATH=`pegasus-config --classpath`
    #ss-display "Pegasus is ready"
}

set_locale() {
    cat >> /etc/environment <<EOF
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8
EOF
}

#apt-get install software-properties-common
deploy_java_ubuntu
deploy_python_ubuntu
deploy_condor_ubuntu
set_locale
deploy_pegasus

# When VM is added, add its address into /etc/hosts

exit 0
