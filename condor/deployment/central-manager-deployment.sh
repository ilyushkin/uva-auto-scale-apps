#!/usr/bin/env bash

set -eufx -o pipefail

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
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" htcondor

#hostnamectl set-hostname $HOSTNAME.htcondor
#apt-get update -y
#apt-get install -y gcc-multilib
#useradd -M -N -r -s /bin/false condor
#condor_name=condor-8.6.4-x86_64_Ubuntu14-stripped
#wget -O /root/$condor_name.tar.gz https://github.com/ilyushkin/uva-auto-scale-apps/blob/master/condor/app/$condor_name.tar.gz?raw=true
#tar xzf /root/$condor_name.tar.gz -C /root
#rm -f /root/$condor_name.tar.gz
#mkdir /root/condor
#mkdir /scratch
#mkdir /scratch/condor
#/root/$condor_name/condor_install --prefix=/root/condor --local-dir=/scratch/condor --type=manager,submit
#rm -rf /root/$condor_name
#cat /root/condor/condor.sh >> /root/.bashrc
#exec bash
#ln -s /root/condor/etc/init.d/condor /etc/init.d/condor
#
#/root/condor/sbin/condor_master &
#/root/condor/sbin/condor_collector &
#/root/condor/sbin/condor_negotiator &
#/root/condor/sbin/condor_schedd &
}

#gh=https://raw.githubusercontent.com
#curl -sSfL $gh/ilyushkin/uva-auto-scale-apps/master/hist-as/deployment/central-manager-deployment.sh | bash

#apt-get install software-properties-common
deploy_java_ubuntu
deploy_python_ubuntu
deploy_condor_ubuntu

exit 0


