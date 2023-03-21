#!/bin/sh
source .env
if [ $# -gt 0 ];then
   vmname=$1
else
   vmname=new-vm-$(date +%y%m%d)-$RANDOM.cloud.kth.se
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
  newname=$(dig +short -x $FREE)
  newname=${newname:0:${#newname}-1}
  vmpath=$(govc vm.info $vmname | grep Path | awk '{print $2}')
  govc object.rename ${vmpath} ${newname}
fi
TS=$(date +%s)
TD=$((TS - 1678217460))
TM=$(expr $TD % 300)
TMD=$((300 - TM))
sleep $TMD
govc vm.power -on ${newname}
IP=$(govc vm.ip ${newname})
echo $IP
ssh ubuntu@$IP
