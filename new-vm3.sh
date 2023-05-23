#!/bin/sh
source .env
if [ ! -f "jammy-server-cloudimg-amd64.ova" ];then
   curl -OL https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.ova
fi
for i in {26..27};do
govc import.spec jammy-server-cloudimg-amd64.ova > spec.json
vmname="rancher-node0${i}.cloud.kth.se"
python3 <<EOF
import json
f=open('spec.json')       
j=json.loads(f.read())
for x in j['PropertyMapping']:
    if x['Key']=='public-keys':
            x['Value']="$SSH_KEY"
    if x['Key']=='hostname':
            x['Value']="${vmname}"
f=open('spec.json','w')
f.write(json.dumps(j))
f.close()
EOF
govc import.ova -name=${vmname} --options=spec.json jammy-server-cloudimg-amd64.ova
govc vm.network.add  -vm=${vmname} -net n210 
govc vm.network.change -vm=${vmname} ethernet-0
govc vm.change -vm ${vmname} -m 8192 -c 2
govc vm.disk.change -vm ${vmname} -size 120G 
MAC=$(govc device.info -vm=${vmname} ethernet-0 | grep "MAC Address" | cut -c 21-37)
MAC2=$(govc device.info -vm=${vmname} ethernet-1 | grep "MAC Address" | cut -c 21-37)
echo "${vmname} ${MAC} ${MAC2}"
done
