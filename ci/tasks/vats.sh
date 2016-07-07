#!/usr/bin/env bash

set -e -x
source rexray-bosh-release/ci/tasks/utils.sh

check_param BOSH_DIRECTOR_PUBLIC_IP
check_param BOSH_PASSWORD
check_param BOSH_USER
check_param DEPLOYMENT_NAME
check_param DEPLOYMENT_PASSWORD
check_param DEPLOYMENT_PRIVATE_KEY
check_param FAKE_VOLUME_NAME
check_param REXRAY_RELEASE_NAME
check_param SCALEIO_ENDPOINT
check_param SCALEIO_INSECURE
check_param SCALEIO_MDM_IPS
check_param SCALEIO_PASSWORD
check_param SCALEIO_PROTECTION_DOMAIN_ID
check_param SCALEIO_PROTECTION_DOMAIN_NAME
check_param SCALEIO_SDC_RELEASE_NAME
check_param SCALEIO_STORAGE_POOL_ID
check_param SCALEIO_STORAGE_POOL_NAME
check_param SCALEIO_SYSTEM_ID
check_param SCALEIO_USER_ID
check_param SCALEIO_USERNAME
check_param SCALEIO_VERSION
check_param VSPHERE_VM_IP

bosh target ${BOSH_DIRECTOR_PUBLIC_IP}
bosh login ${BOSH_USER} ${BOSH_PASSWORD}

cat > scaleio-acceptance-manifest.yml <<EOF
---
name: scaleio_rexray
director_uuid: cd0eb8bc-831e-447d-99c1-9658c76e7721
stemcells:
- alias: trusty
  os: ubuntu-trusty
  version: '3215'
releases:
- name: rexray-bosh-release
  version: latest
- name: scaleio-sdc-bosh-release
  version: latest
jobs:
- name: scaleio_rexray
  instances: 1
  templates:
  - name: setup_sdc
    release: scaleio-sdc-bosh-release
  - name: rexray_service
    release: rexray-bosh-release
  vm_type: medium
  stemcell: trusty
  azs:
  - z1
  networks:
  - name: private
    static_ips:
    - ${VSPHERE_VM_IP}
  properties:
    network_name: private
properties:
  scaleio:
    mdm:
      ips: ${SCALEIO_MDM_IPS}
  rexray: |
    ---
    rexray:
      modules:
        default-admin:
          desc: The default admin module.
          disabled: false
          host: tcp://127.0.0.1:7979
          type: admin
        default-docker:
          desc: The default docker module.
          disabled: false
          host: tcp://127.0.0.1:9000
          spec: /etc/docker/plugins/rexray.spec
          type: docker
      libstorage:
        embedded: true
        driver: scaleio
        service: scaleio
    scaleio:
      endpoint: ${SCALEIO_ENDPOINT}
      insecure: ${SCALEIO_INSECURE}
      password: ${SCALEIO_PASSWORD}
      protectionDomainName: default
      storagePoolName: ${SCALEIO_STORAGE_POOL_NAME}
      systemID: ${SCALEIO_SYSTEM_ID}
      thinOrThick: ThinProvisioned
      useCerts: false
      userID: ${SCALEIO_USER_ID}
      userName: ${SCALEIO_USERNAME}
      version: ${SCALEIO_VERSION}
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

pushd scaleio-sdc-bosh-release
  bosh -n create release --force --name ${SCALEIO_SDC_RELEASE_NAME}
  bosh -n upload release
popd

pushd rexray-bosh-release
  bosh -n create release --force --name ${REXRAY_RELEASE_NAME}
  bosh -n upload release
popd

function cleanUp {
  local status=$?
  bosh -n delete deployment ${DEPLOYMENT_NAME}
  bosh -n delete release ${REXRAY_RELEASE_NAME}
  bosh -n delete release ${SCALEIO_SDC_RELEASE_NAME}
  exit $status
}
trap cleanUp EXIT

bosh -n deploy

function ssh_run() {
  sshpass -p ${DEPLOYMENT_PASSWORD} ssh -o "StrictHostKeyChecking no" vcap@${VSPHERE_VM_IP} \
    "echo ${DEPLOYMENT_PASSWORD} | sudo -S bash -c ' $* '"
}

cat > config.json <<EOF
{
  "volman_driver_path": "/etc/docker/plugins",
  "driver_name": "rexray",
  "create_config": {
    "Name": "${FAKE_VOLUME_NAME}",
    "Opts": {}
  }
}
EOF

sshpass -p ${DEPLOYMENT_PASSWORD} scp -o StrictHostKeyChecking=no config.json vcap@${VSPHERE_VM_IP}:/home/vcap/

cat > run_test.sh <<EOF
set -x
wget --no-check-certificate https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
tar -zxf go1.6.2.linux-amd64.tar.gz -C ./
export GOROOT=/home/vcap/go
export GOOS=linux
export GOARCH=amd64
export PATH=\$PATH:\$GOROOT/bin

mkdir -p gocode
export GOPATH=/home/vcap/gocode
export PATH=\$PATH:\$GOPATH/bin

/var/vcap/packages/rexray/rexray volume create --volumename ${FAKE_VOLUME_NAME} --size 8 || true

apt-get -y update && apt-get -y install git && apt-get -y install jq

mkdir -p \$GOPATH/src/gopkg.in/
cd \$GOPATH/src/gopkg.in/
git clone https://github.com/go-yaml/yaml.git yaml.v2
go install gopkg.in/yaml.v2

mkdir -p \$GOPATH/src/github.com/onsi
cd \$GOPATH/src/github.com/onsi

git clone https://github.com/onsi/ginkgo.git
git clone https://github.com/onsi/gomega.git
go install github.com/onsi/ginkgo/ginkgo
go install github.com/onsi/gomega

go get --insecure -f -u github.com/cloudfoundry-incubator/volume_driver_cert
go get --insecure -f -u code.cloudfoundry.org/clock
cd \$GOPATH/src/github.com/cloudfoundry-incubator/volume_driver_cert

printf "http://127.0.0.1:9000" > /etc/docker/plugins/rexray.spec

export FIXTURE_FILENAME=/home/vcap/config.json
ginkgo -r

/var/vcap/packages/rexray/rexray volume unmount --volumename ${FAKE_VOLUME_NAME} || true
/var/vcap/packages/rexray/rexray volume remove --volumeid $(/var/vcap/packages/rexray/rexray volume get --volumename ${FAKE_VOLUME_NAME} -f json | jq .id -r)
EOF

chmod +x run_test.sh
sshpass -p ${DEPLOYMENT_PASSWORD} scp -o StrictHostKeyChecking=no run_test.sh vcap@${VSPHERE_VM_IP}:/home/vcap/

ssh_run ./run_test.sh
