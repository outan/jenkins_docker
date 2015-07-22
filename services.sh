#!/bin/bash
/sbin/service sshd start
/bin/tini -- /usr/local/bin/jenkins.sh
while true
do
    sleep 10
done
