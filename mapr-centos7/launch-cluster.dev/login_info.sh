#!/bin/bash

publicHostname=$(hostname -f)

onAWS() {
  # Running in AWS
  [[ -f /sys/hypervisor/uuid ]] && \
    [[ "$(head -c 3 /sys/hypervisor/uuid)" = "ec2" ]] && \
    return 0

  [[ -f /sys/devices/virtual/dmi/id/product_uuid ]] && \
    [[ "$(sudo cat /sys/devices/virtual/dmi/id/product_uuid | head -c 3 )" = "EC2" ]] && \
    return 0

  return 1
}

onAzure() {
  [[ -d /var/lib/waagent ]] && return 0
  return 1
}

onAWS && publicHostname=$(curl http://169.254.169.254/latest/meta-data/public-hostname 2>/dev/null)
onAzure && publicHostname=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-08-01&format=json"  2>/dev/null \
                   | jq -r .network.interface[].ipv4.ipAddress[].publicIpAddress )

#echo "Gathering cluster information..."

# echo "  Docker containers..."
sudo docker ps > /tmp/dockerInfo.txt
#echo ""
echo "Running Docker containers:"
cat /tmp/dockerInfo.txt | sed -e 's/^/  /'

proxyPort=$(cat /tmp/dockerInfo.txt| grep '\-webproxy$' | rev | cut -d: -f 1 | rev | cut -f 1 -d '-')
for dockerCluster in $(cat /tmp/dockerInfo.txt| grep '\-s1$' | rev | cut -d' ' -f 1 | rev | sed -e 's/-s1//'); do
  maprNodeSshPort=
  maprNodeSshPort="$(cat /tmp/dockerInfo.txt| grep "[[:space:]]${dockerCluster}-s1$" | tr ',' '\n' | grep '>22' | rev | cut -d: -f 1 | rev | cut -f 1 -d '-')"
  launcherSshPort="$(cat /tmp/dockerInfo.txt| grep "[[:space:]]${dockerCluster}-c[0-9]\+\-launcher$" | rev | cut -d: -f 1 | rev | cut -f 1 -d '-')"
  #launcherSshPort=$(cat /tmp/dockerInfo.txt | grep "$clusterName"'\-c[0-9]\+\-launcher$' | rev | cut -d: -f 1 | rev | cut -f 1 -d '-')
  echo ""
  echo "Gathering MapR Cluster information from container on port $maprNodeSshPort ..."
  sshpass -p mapr ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $maprNodeSshPort root@localhost maprcli dashboard info -json > /tmp/maprDashboard.json
  clusterName=$(jq -r  .data[].cluster.name      /tmp/maprDashboard.json)
  nodeCount=$(  jq -r  .data[].cluster.nodesUsed /tmp/maprDashboard.json)
  clusterId=$(  jq -r  .data[].cluster.id        /tmp/maprDashboard.json)
  maprVersion=$(jq -r  .data[].version           /tmp/maprDashboard.json)
  
  echo "Gathering MapR Services information from container on port $maprNodeSshPort ..."
  sshpass -p mapr ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $maprNodeSshPort root@localhost maprcli node list -columns svc > /tmp/maprServices.txt
  apiServer=$(cat /tmp/maprServices.txt | grep -e apiserver -e webserver | head -1 | cut -f 1 -d ' ')
  
  
  clusterNameHeader=$clusterName
  [[ "$clusterName" != "$dockerCluster" ]] && clusterNameHeader+=" ($dockerCluster)"
  printf "%s   %s   %s\n" "==============================" "$clusterNameHeader" "==============================" 
  echo ""
  echo "MapR Cluster Info"
  printf "  %-14s%-14s\n" "Cluster Name:" $clusterName
  printf "  %-14s%-14s\n" "Cluster ID:" $clusterId
  printf "  %-14s%-14s\n" "MapR Version:" $maprVersion
  printf "  %-14s%-14s\n" "Node Count:" $nodeCount
  # echo "  For all MapR Enterprise capabilities including high availability, retrieve a Converged Enterprise Trial license at https://mapr.com/user"
  echo ""
  echo "MapR cluster running services:"
  cat /tmp/maprServices.txt | sed -e 's/^/  /'
  echo ""
  echo "MapR Control System:"
  echo "  https://$apiServer:8443 (user:mapr password:mapr)"
  echo "  To use docker hostname $apiServer, set browser proxy (Firefox: Preferences/Network Proxy/Settings/Manual proxy configuration):"
  printf "    ProxyHost: %s  Port: %s\n" $publicHostname $proxyPort
  echo ""
  echo "Log in to edge node as root user:"
  echo "  sshpass -p mapr ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $launcherSshPort root@localhost"
  echo ""
  echo "Log in to a MapR cluster node as root user:"
  echo "  sshpass -p mapr ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $maprNodeSshPort root@localhost"
  echo ""
done

if $onAWS ; then
  echo "=============================="
  echo ""
  echo "AWS startup info:"
  sudo rm -f /tmp/docker-cluster-cloud-init.log
  for file in $(ls -1tr /var/log/messages*) ; do sudo grep 'cloud-init:' $file >> /tmp/docker-cluster-cloud-init.log ; done
  if [[ -f /var/log/cloud-init-output.log ]] ; then
    echo "  Instance and cluster startup output at /var/log/cloud-init-output.log or /tmp/docker-cluster-cloud-init.log"
  else
    echo "  Instance and cluster startup output at /tmp/docker-cluster-cloud-init.log"
  fi
  [[ -f /var/lib/cloud/instance/user-data.txt ]] && \
  echo "  Startup (user data) script at /var/lib/cloud/instance/user-data.txt" && \
  echo ""
fi
