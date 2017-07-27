#!/usr/bin/env bash

useradd -M -N -r -s /bin/false condor
wget http://parrot.cs.wisc.edu//symlink/20170727031502/8/8.6/8.6.4/e5147c3201f2dfa456465a19e67b313f/condor-8.6.4-x86_64_Ubuntu14-stripped.tar.gz
tar xzf condor-8.6.4-x86_64_Ubuntu14-stripped.tar.gz
cd condor-8.6.4-x86_64_Ubuntu14-stripped
mkdir /scratch
condor_install --prefix=~condor --local-dir=/scratch/condor --type=manager
