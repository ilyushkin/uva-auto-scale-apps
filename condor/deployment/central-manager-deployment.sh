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
#export DEBIAN_FRONTEND=noninteractive
#apt-get install -y htcondor
apt-get update -y
apt-get install -y gcc-multilib
useradd -M -N -r -s /bin/false condor
condor_name=condor-8.6.4-x86_64_Ubuntu14-stripped
wget http://parrot.cs.wisc.edu/symlink/20170727031502/8/8.6/8.6.4/e5147c3201f2dfa456465a19e67b313f/$condor_name.tar.gz
tar xzf $condor_name.tar.gz
rm -f $condor_name.tar.gz
mkdir /root/condor
mkdir /scratch
mkdir /scratch/condor
/root/$condor_name/condor_install --prefix=/root/condor --local-dir=/scratch/condor --type=manager,submit
rm -rf $condor_name
cat /root/condor/condor.sh | bash

/root/condor/sbin/condor_master
}

#gh=https://raw.githubusercontent.com
#curl -sSfL $gh/ilyushkin/uva-auto-scale-apps/master/hist-as/deployment/central-manager-deployment.sh | bash

deploy_java_ubuntu
deploy_python_ubuntu
deploy_condor_ubuntu


