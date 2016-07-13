#!/usr/bin/env bash

set -e -x
source rexray-bosh-release/ci/tasks/utils.sh

check_param BOSH_DIRECTOR_PUBLIC_IP
check_param BOSH_PASSWORD
check_param BOSH_USER
check_param DEPLOYMENT_PASSWORD
check_param FAKE_VOLUME_NAME
check_param REXRAY_RELEASE_NAME
check_param VOLUME_DRIVER_ADDRESS

check_param ISILON_VATS_DEPLOYMENT_NAME
check_param ISILON_ENDPOINT
check_param ISILON_INSECURE
check_param ISILON_USERNAME
check_param ISILON_PASSWORD
check_param ISILON_VOLUME_PATH
check_param ISILON_ENDPOINT
check_param ISILON_DATA_SUBNET
check_param ISILON_VSPHERE_VM_IP

bosh target ${BOSH_DIRECTOR_PUBLIC_IP}
bosh login ${BOSH_USER} ${BOSH_PASSWORD}

cat > scaleio-acceptance-manifest.yml <<EOF
---
name: ${ISILON_VATS_DEPLOYMENT_NAME}
director_uuid: cd0eb8bc-831e-447d-99c1-9658c76e7721
stemcells:
- alias: trusty
  os: ubuntu-trusty
  version: '3215'
releases:
- name: rexray-release
  version: latest
jobs:
- name: ${ISILON_VATS_DEPLOYMENT_NAME}
  instances: 1
  templates:
  - name: rexray_service
    release: rexray-release
  vm_type: medium
  stemcell: trusty
  azs:
  - z1
  networks:
  - name: private
    static_ips:
    - ${ISILON_VSPHERE_VM_IP}
  properties:
    network_name: private
properties:
  rexray: |
    ---
    rexray:
      modules:
        isilon:
          disabled: false
          host: tcp://127.0.0.1:9000
          spec: /var/vcap/data/voldrivers/rexray_isilon.spec
          http:
            writetimeout: 900
            readtimeout: 900
          type: docker
          libstorage:
            service: isilon
      libstorage:
        embedded: true
        server:
          services:
            isilon:
              driver: isilon
    isilon:
      endpoint: https://${ISILON_ENDPOINT}:8080
      insecure: ${ISILON_INSECURE}
      username: ${ISILON_USERNAME}
      password: ${ISILON_PASSWORD}
      volumePath: ${ISILON_VOLUME_PATH}
      nfsHost: ${ISILON_ENDPOINT}
      dataSubnet: ${ISILON_DATA_SUBNET}
      quotas: false
      sharedMounts: true
    linux:
      volume:
        fileMode: 0777
update:
  canaries: 1
  max_in_flight: 3
  canary_watch_time: 30000-600000
  update_watch_time: 5000-600000

EOF
cat scaleio-acceptance-manifest.yml
bosh deployment scaleio-acceptance-manifest.yml

apt-get -y update && apt-get -y install sshpass

pushd rexray-bosh-release
  bosh -n create release --force --name ${REXRAY_RELEASE_NAME}
  bosh -n upload release
popd

function cleanUp {
  local status=$?
  bosh -n delete deployment ${ISILON_VATS_DEPLOYMENT_NAME}
  bosh -n delete release ${REXRAY_RELEASE_NAME} || true
  exit $status
}
trap cleanUp EXIT

bosh -n deploy

function ssh_run() {
  sshpass -p ${DEPLOYMENT_PASSWORD} ssh -o "StrictHostKeyChecking no" vcap@${ISILON_VSPHERE_VM_IP} \
    "echo ${DEPLOYMENT_PASSWORD} | sudo -S bash -c ' $* '"
}

cat > config.json <<EOF
{
  "volman_driver_path": "/etc/docker/plugins",
  "driver_address": "${VOLUME_DRIVER_ADDRESS}",
  "driver_name": "rexray",
  "create_config": {
    "Name": "${FAKE_VOLUME_NAME}",
    "Opts": {}
  }
}
EOF

sshpass -p ${DEPLOYMENT_PASSWORD} scp -o StrictHostKeyChecking=no config.json vcap@${ISILON_VSPHERE_VM_IP}:/home/vcap/

cat > run_test.sh <<EOF
set -x

add-apt-repository -y ppa:ubuntu-lxc/lxd-stable
apt-get -y update
apt-get -y install golang
apt-get -y install git

mkdir -p gocode
export GOPATH=/home/vcap/gocode
export PATH=\$PATH:\$GOPATH/bin

go get --insecure -f -u gopkg.in/yaml.v2
go get --insecure -f -u github.com/onsi/ginkgo/ginkgo
go get --insecure -f -u github.com/onsi/gomega
go get --insecure -f -u github.com/cloudfoundry-incubator/volume_driver_cert
go get --insecure -f -u code.cloudfoundry.org/clock
cd \$GOPATH/src/github.com/cloudfoundry-incubator/volume_driver_cert

export FIXTURE_FILENAME=/home/vcap/config.json
ginkgo -r
EOF

chmod +x run_test.sh
sshpass -p ${DEPLOYMENT_PASSWORD} scp -o StrictHostKeyChecking=no run_test.sh vcap@${ISILON_VSPHERE_VM_IP}:/home/vcap/

ssh_run ./run_test.sh
