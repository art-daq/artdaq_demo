#!/bin/bash

num_events=${1:-100}

sed -i "s/num_events:.*/num_events: $num_events/g" driver.fcl validate.fcl

artdaqDriver -c driver.fcl
trap "rm driver.root" EXIT
res=$?

if [ $res -ne 0 ]; then
    exit $res
fi

art -c validate.fcl driver.root
res=$?

if [ $res -ne 0 ];then
    exit $res
fi

