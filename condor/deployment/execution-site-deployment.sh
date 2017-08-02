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
var="127.0.0.1 localhost localhost.localdomain $HOSTNAME.local"
sed -i "1s/.*/$var/" /etc/hosts
hostnamectl set-hostname $HOSTNAME.local
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" htcondor
collector_host='ss-get cmhostname'
echo "COLLECTOR_HOST = $collector_host" >> /etc/condor/condor_config.local
echo "DAEMON_LIST = MASTER, STARTD" >> /etc/condor/condor_config.local
service condor restart
}

deploy_pegasus() {
wget -O - http://download.pegasus.isi.edu/pegasus/gpg.txt | sudo apt-key add -
echo 'deb [arch=amd64] http://download.pegasus.isi.edu/pegasus/ubuntu trusty main' | sudo tee /etc/apt/sources.list.d/pegasus.list
apt-get update -q
apt-get install pegasus -y
export PYTHONPATH=`pegasus-config --python`
export PERL5LIB=`pegasus-config --perl`
export CLASSPATH=`pegasus-config --classpath`
}

#apt-get install software-properties-common
deploy_java_ubuntu
deploy_python_ubuntu
deploy_condor_ubuntu
#deploy_pegasus

exit 0


