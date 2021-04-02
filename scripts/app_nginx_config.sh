#!/bin/bash
sa=`cat ./output/host_ips.txt | head -1`
sb=`cat ./output/host_ips.txt | tail -1`

echo $sa
echo $sb

sed -i "s/appserver1/$sa/g" ./scripts/nginx.conf
sed -i "s/appserver2/$sb/g" ./scripts/nginx.conf
