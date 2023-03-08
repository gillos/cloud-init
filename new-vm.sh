#!/bin/sh
source .env
if [ $# -eq 0 ];then
   echo "Usage: ./new.sh vmname"
   exit
else
   vmname=$1
fi
if [ ! -f "jammy-server-cloudimg-amd64.ova" ];then
   curl -OL https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.ova
fi
govc import.spec jammy-server-cloudimg-amd64.ova > spec.json
python3 <<EOF
import json
f=open('spec.json')       
j=json.loads(f.read())
for x in j['PropertyMapping']:
    if x['Key']=='public-keys':
            x['Value']="$SSH_KEY"
    if x['Key']=='hostname':
            x['Value']="$vmname"
f=open('spec.json','w')
f.write(json.dumps(j))
f.close()
EOF
govc import.ova -name=${vmname} --options=spec.json jammy-server-cloudimg-amd64.ova
govc vm.network.change -vm=${vmname} ethernet-0
govc vm.change -vm ${vmname} -m 8192 -c 2
govc vm.disk.change -vm ${vmname} -size 120G 
MAC=$(govc device.info -vm=${vmname} ethernet-0 | grep "MAC Address" | cut -c 21-37)
RES=$(curl -s -H "apilabel:$KIDDOW_KEY" -H "apisecret:$KIDDOW_SECRET" $KIDDOW_URL/api/v0/find_free_ipaddress?subnet=$KIDDOW_SUBNET)
echo $RES
if [[ $RES =~ "not-found" ]];then
   echo "NO FREE IP"
   exit
else
  echo $RES
  FREE=$(echo $RES | cut -c 7-)
  echo $FREE
  RES=$(curl -s -X POST -H "apilabel:$KIDDOW_KEY" -H "apisecret:$KIDDOW_SECRET" -d "ipaddress=$FREE" -d "macaddress=$MAC" $KIDDOW_URL/api/v0/set_static_ip)
  echo $RES
fi
TS=$(date +%s)
TD=$((TS - 1678217460))
TM=$(expr $TD % 300)
TMD=$((300 - TM))
sleep $TMD
govc vm.power -on ${vmname}
IP=$(govc vm.ip  ${vmname})
echo $IP
ssh ubuntu@$IP
