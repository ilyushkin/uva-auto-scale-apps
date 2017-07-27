#!/usr/bin/env bash


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
apt-get update -y
DEBIAN_FRONTEND=noninteractive
apt-get install -y condor
/etc/init.d/condor restart
}

deploy_condor_ubuntu() {
useradd -u 1000 -g 500 condor
usermod -s /sbin/nologin condor
wget http://parrot.cs.wisc.edu//symlink/20170727031502/8/8.6/8.6.4/e5147c3201f2dfa456465a19e67b313f/condor-8.6.4-x86_64_Ubuntu14-stripped.tar.gz
tar xzf condor-8.6.4-x86_64_Ubuntu14-stripped.tar.gz
cd condor-8.6.4-x86_64_Ubuntu14-stripped
mkdir /scratch
condor_install --prefix=~condor --local-dir=/scratch/condor --type=manager

}


#!/bin/bash
set -e
set -x
set -o pipefail

gh=https://raw.githubusercontent.com
curl -sSfL $gh/ilyushkin/uva-auto-scale-apps/master/hist-as/deployment/deployment.sh | bash


