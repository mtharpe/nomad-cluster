#!/bin/bash

set -e

#############################################################################################################################
#   Environment
#############################################################################################################################
DATA_CENTER="dc1"
CONSUL_VERSION="1.7.2"
NOMAD_VERSION="0.11.0"
AGENT_TYPE="client"
RETRY_JOIN=""
SERVER_COUNT=1

#   Grab Arguments
while getopts d:c:n:a:r:s: option
do
case "${option}"
in
d) DATA_CENTER=${OPTARG};;
c) CONSUL_VERSION=${OPTARG};;
n) NOMAD_VERSION=${OPTARG};;
a) AGENT_TYPE=${OPTARG};;
r) RETRY_JOIN=${OPTARG};;
s) SERVER_COUNT=${OPTARG};;
esac
done

#   Utils
echo "Updating and Installing Utilities"
sudo yum update -y
sudo yum install unzip -y
sudo yum install java -y

#   Move to Temp Directory
cd /tmp

#############################################################################################################################
#   Consul
#############################################################################################################################
#   Download
curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

#   Install
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/bin/
sudo consul -autocomplete-install
complete -C /usr/bin/consul consul
sudo setcap cap_ipc_lock=+ep /usr/bin/consul
sudo rm consul_${CONSUL_VERSION}_linux_amd64.zip

sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

sudo mkdir --parents /etc/consul.d
sudo chown --recursive consul:consul /etc/consul.d

if [ $AGENT_TYPE = "server" ]
then
cat <<-EOF > /etc/consul.d/consul.hcl
datacenter = "${DATA_CENTER}"
data_dir = "/opt/consul"
client_addr = "0.0.0.0"
ui = true
server = true
bootstrap_expect = ${SERVER_COUNT}

retry_join = [ ${RETRY_JOIN} ]

performance {
  raft_multiplier = 1
}
EOF
else
cat <<-EOF > /etc/consul.d/consul.hcl
datacenter = "${DATA_CENTER}"
data_dir = "/opt/consul"
client_addr = "0.0.0.0"
retry_interval = "5s"
retry_join = [ ${RETRY_JOIN} ]

performance {
  raft_multiplier = 1
}
EOF
fi

cat <<-EOF > /etc/systemd/system/consul.service
[Unit]
Description="consul"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#   Enable the Service
sudo systemctl enable consul
sudo service consul start

#############################################################################################################################
#   Nomad
#############################################################################################################################
#   Download
curl --silent --remote-name https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip

#   Install
unzip nomad_${NOMAD_VERSION}_linux_amd64.zip
sudo chown root:root nomad
sudo mv nomad /usr/bin/
sudo nomad -autocomplete-install
complete -C /usr/bin/nomad nomad
sudo setcap cap_ipc_lock=+ep /usr/bin/nomad
sudo rm nomad_${NOMAD_VERSION}_linux_amd64.zip

sudo mkdir -p /etc/nomad.d

if [ $AGENT_TYPE = "server" ]
then
cat <<-EOF > /etc/nomad.d/nomad.hcl
datacenter = "${DATA_CENTER}"
data_dir = "/opt/nomad"
bind_addr = "0.0.0.0"

server {
    enabled = true
    bootstrap_expect = ${SERVER_COUNT}
}

consul {
    address = "127.0.0.1:8500"
}

vault {
    enabled = false
    address = "<Add Vault API Address Here>"
    token = "<Add Vault Token Here>"
}
EOF
else
cat <<-EOF > /etc/nomad.d/nomad.hcl
datacenter = "${DATA_CENTER}"
data_dir = "/opt/nomad"
bind_addr = "0.0.0.0"

client {
    enabled = true
    servers = [ ${RETRY_JOIN} ]
}

consul {
    address = "127.0.0.1:8500"
}

vault {
    enabled = false
    address = "<Add Vault API Address Here>"
}
EOF
fi

cat <<-EOF > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

# When using Nomad with Consul it is not necessary to start Consul first. These
# lines start Consul before Nomad as an optimization to avoid Nomad logging
# that Consul is unavailable at startup.
Wants=consul.service
After=consul.service

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF

#   Enable the Service
sudo systemctl enable nomad
sudo service nomad start

#############################################################################################################################
#   Setup BIND Port Forwarding
#############################################################################################################################
sudo yum install bind bind-utils -y

cat <<-EOF > /etc/named.conf
options {
  listen-on port 53 { 127.0.0.1; };
  listen-on-v6 port 53 { ::1; };
  directory       "/var/named";
  dump-file       "/var/named/data/cache_dump.db";
  statistics-file "/var/named/data/named_stats.txt";
  memstatistics-file "/var/named/data/named_mem_stats.txt";
  allow-query     { localhost; };
  recursion yes;

  dnssec-enable no;
  dnssec-validation no;

  /* Path to ISC DLV key */
  bindkeys-file "/etc/named.iscdlv.key";

  managed-keys-directory "/var/named/dynamic";
};

include "/etc/named/consul.conf";
EOF

cat <<-EOF > /etc/named/consul.conf
zone "consul" IN {
  type forward;
  forward only;
  forwarders { 127.0.0.1 port 8600; };
};
EOF

sudo systemctl enable named
sudo systemctl restart named
sudo firewall-cmd --permanent --add-port=53/udp
sudo firewall-cmd --reload

exit 0