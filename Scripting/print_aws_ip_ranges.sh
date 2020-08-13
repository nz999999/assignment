#!/bin/bash

URL='https://ip-ranges.amazonaws.com/ip-ranges.json'
region=$1


curl -s $URL | grep "$region" &> /dev/null || (echo "error: invalid region";exit 10)
curl -s $URL | grep -B1 "region.*${region}" | grep prefix | awk -F\" '{print $4}'
sum=`curl -s $URL | grep -B1 "region.*${region}" | grep prefix | awk -F\" '{print $4}' | wc -l`
echo "The total sum of the numbers: $sum"

