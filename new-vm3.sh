#!/bin/sh
source .env
if [ ! -f "jammy-server-cloudimg-amd64.ova" ];then
   curl -OL https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.ova
fi
FROMN=19
TON=21
for i in {$FROMN..$TON};do
govc import.spec jammy-server-cloudimg-amd64.ova > spec.json
vmname="rancher-node0${i}.cloud.kth.se"
python3 <<EOF
import json
f=open('spec.json')       
j=json.loads(f.read())
j['DiskProvisioning']='thin'
for x in j['PropertyMapping']:
    if x['Key']=='public-keys':
            x['Value']="$SSH_KEY"
    if x['Key']=='hostname':
            x['Value']="${vmname}"
f=open('spec.json','w')
f.write(json.dumps(j))
f.close()
EOF
govc library.deploy --options=spec.json /ova/jammy-server-cloudimg-amd64 ${vmname}
govc vm.network.change -vm=${vmname} ethernet-0
govc vm.change -vm ${vmname} -m 8192 -c 2
govc vm.disk.change -vm ${vmname} -size 120G 
MAC=$(govc device.info -vm=${vmname} ethernet-0 | grep "MAC Address" | cut -c 21-37)
IP="130.237.255.$i"
RES=$(curl -s -X POST -H "apilabel:$KIDDOW_KEY" -H "apisecret:$KIDDOW_SECRET" -d "ipaddress=$IP" -d "macaddress=$MAC" $KIDDOW_URL/api/v0/set_static_ip)
echo "${vmname} ${MAC}"
done
TS=$(date +%s)
TD=$((TS - 1678217460))
TM=$(expr $TD % 300)
TMD=$((300 - TM))
sleep $TMD
for i in {$FROMN..$TON};do
vmname="rancher-node0${i}.cloud.kth.se"
govc vm.power -on ${vmname}
done
sleep 60
for i in {$FROMN..$TON};do
vmname="rancher-node0${i}.cloud.kth.se"
govc vm.network.add  -vm=${vmname} -net v861
done
