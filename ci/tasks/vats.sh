#!/usr/bin/env bash

set -e -x
source rexray-bosh-release/ci/tasks/utils.sh

check_param AWS_ELASTIC_IP
check_param AWS_SECURITY_GROUP
check_param AWS_SUBNET_ID
check_param BOSH_DIRECTOR_PUBLIC_IP
check_param BOSH_PASSWORD
check_param BOSH_USER
check_param DEPLOYMENT_NAME
check_param DEPLOYMENT_PASSWORD
check_param DEPLOYMENT_PRIVATE_KEY
check_param FAKE_VOLUME_NAME
check_param REXRAY_RELEASE_NAME
check_param SCALEIO_ENDPOINT
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

bosh target ${BOSH_DIRECTOR_PUBLIC_IP}
bosh login ${BOSH_USER} ${BOSH_PASSWORD}
bosh upload stemcell stemcell/stemcell.tgz || true

cat > scaleio-acceptance-manifest.yml <<EOF
---
name: ${DEPLOYMENT_NAME}
director_uuid: $(bosh status --uuid)

releases:
- name: ${SCALEIO_SDC_RELEASE_NAME}
  version: latest
- name: ${REXRAY_RELEASE_NAME}
  version: latest

disk_pools:
- name: disks
  disk_size: 20_000
  cloud_properties: {type: gp2}

resource_pools:
- name: vms
  network: private
  stemcell:
    name: bosh-aws-xen-hvm-ubuntu-trusty-go_agent
    version: 3215
  cloud_properties:
    instance_type: m3.medium
    ephemeral_disk: {size: 25_000, type: gp2}
    availability_zone: us-east-1a

networks:
- name: private
  type: manual
  subnets:
  - range: 10.0.0.0/16
    gateway: 10.0.0.1
    dns: [10.0.0.1]
    reserved:
    - 10.0.0.2 - 10.0.0.18
    static:
    - 10.0.0.20
    cloud_properties:
      subnet: ${AWS_SUBNET_ID}
      security_groups:
        - ${AWS_SECURITY_GROUP}
- name: public
  type: vip

jobs:
- name: scaleio-sdc-with-rexray
  instances: 1
  templates:
  - {name: setup_sdc, release: ${SCALEIO_SDC_RELEASE_NAME}}
  - {name: rexray_service , release: ${REXRAY_RELEASE_NAME}}
  resource_pool: vms
  networks:
  - name: private
    static_ips: [10.0.0.20]
    default: [dns, gateway]
  - name: public
    static_ips: [${AWS_ELASTIC_IP}]
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
          http:
            writetimeout: 120
            readtimeout: 120
          spec: /etc/docker/plugins/rexray.spec
          type: docker
      libstorage:
        embedded: true
        driver: scaleio
        service: scaleio
    scaleio:
      endpoint: ${SCALEIO_ENDPOINT}
      insecure: true
      password: ${SCALEIO_PASSWORD}
      protectionDomainID: ${SCALEIO_PROTECTION_DOMAIN_ID}
      protectionDomainName: ${SCALEIO_PROTECTION_DOMAIN_NAME}
      storagepoolID: ${SCALEIO_STORAGE_POOL_ID}
      storagePoolName: ${SCALEIO_STORAGE_POOL_NAME}
      systemID: ${SCALEIO_SYSTEM_ID}
      thinOrThick: ThinProvisioned
      useCerts: true
      userID: ${SCALEIO_USER_ID}
      userName: ${SCALEIO_USERNAME}
      version: ${SCALEIO_VERSION}
    linux:
      volume:
        fileMode: 0777
compilation:
  workers: 1
  network: private
  reuse_compilation_vms: true
  cloud_properties:
    name: random
    instance_type: m3.medium
    availability_zone: us-east-1a

update:
  canaries: 1
  max_in_flight: 3
  canary_watch_time: 30000-600000
  update_watch_time: 5000-600000
EOF
cat scaleio-acceptance-manifest.yml
bosh deployment scaleio-acceptance-manifest.yml

pushd scaleio-sdc-bosh-release
  bosh -n create release --force --name ${SCALEIO_SDC_RELEASE_NAME}
  bosh -n upload release
popd

pushd rexray-bosh-release
  bosh -n create release --force --name ${REXRAY_RELEASE_NAME}
  bosh -n upload release
popd

function cleanUp {
  bosh -n delete deployment ${DEPLOYMENT_NAME}
  bosh -n delete release ${REXRAY_RELEASE_NAME}
  bosh -n delete release ${SCALEIO_SDC_RELEASE_NAME}
}
trap cleanUp EXIT

bosh -n deploy

echo "${DEPLOYMENT_PRIVATE_KEY}" > bosh.pem
chmod 600 bosh.pem
function ssh_run() {
  ssh -o "StrictHostKeyChecking no" -i bosh.pem vcap@${AWS_ELASTIC_IP} \
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
scp -o StrictHostKeyChecking=no -i bosh.pem config.json vcap@${AWS_ELASTIC_IP}:/home/vcap/

cat > run_test.sh <<EOF
set -x
wget https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
tar -zxf go1.6.2.linux-amd64.tar.gz -C ./
export GOROOT=/home/vcap/go
export PATH=\$PATH:\$GOROOT/bin

mkdir -p gocode
export GOPATH=/home/vcap/gocode
export PATH=\$PATH:\$GOPATH/bin

/var/vcap/packages/rexray/rexray volume create --volumename ${FAKE_VOLUME_NAME} --size 8 || true

apt-get -y update && apt-get -y install git
go get github.com/onsi/ginkgo/ginkgo
go get github.com/onsi/gomega
go get github.com/cloudfoundry-incubator/volume_driver_cert
go install github.com/onsi/ginkgo/ginkgo

cd \$GOPATH/src/github.com/cloudfoundry-incubator/volume_driver_cert
go get -t ./...

printf "http://127.0.0.1:9000" > /etc/docker/plugins/rexray.spec

export FIXTURE_FILENAME=/home/vcap/config.json
ginkgo

/var/vcap/packages/rexray/rexray volume unmount --volumename ${FAKE_VOLUME_NAME} || true
EOF
chmod +x run_test.sh
scp -o StrictHostKeyChecking=no -i bosh.pem run_test.sh vcap@${AWS_ELASTIC_IP}:/home/vcap/
ssh_run ./run_test.sh
