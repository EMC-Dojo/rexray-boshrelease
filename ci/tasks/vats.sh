#!/usr/bin/env bash

set -e -x

source rexray-bosh-release/ci/tasks/utils.sh

check_param BOSH_DIRECTOR_PUBLIC_IP
check_param BOSH_USER
check_param BOSH_PASSWORD
check_param DEPLOYMENT_PRIVATE_KEY
check_param DEPLOYMENT_PASSWORD
check_param AWS_SUBNET_ID
check_param AWS_SECURITY_GROUP
check_param AWS_ELASTIC_IP
check_param SDC_RELEASE_NAME
check_param REXRAY_RELEASE_NAME
check_param SCALEIO_ACCEPTANCE_DEPLOYMENT_NAME
check_param MDM_IP
check_param REXRAY_CONFIG

# bosh target $BOSH_DIRECTOR_PUBLIC_IP
# bosh login $BOSH_USER $BOSH_PASSWORD
#
# cat > "scaleio-acceptance-manifest.yml" <<EOF
# ---
# name: ${SCALEIO_ACCEPTANCE_DEPLOYMENT_NAME}
#
# director_uuid: $(bosh status --uuid)
#
# releases:
# - name: ${SDC_RELEASE_NAME}
#   version: latest
# - name: ${REXRAY_RELEASE_NAME}
#   version: latest
#
# disk_pools:
# - name: disks
#   disk_size: 20_000
#   cloud_properties: {type: gp2}
#
# resource_pools:
# - name: vms
#   network: private
#   stemcell:
#     name: bosh-aws-xen-hvm-ubuntu-trusty-go_agent
#     version: latest
#   cloud_properties:
#     instance_type: m3.medium
#     ephemeral_disk: {size: 25_000, type: gp2}
#     availability_zone: us-east-1a
#
# networks:
# - name: private
#   type: manual
#   subnets:
#   - range: 10.0.0.0/16
#     gateway: 10.0.0.1
#     dns: [10.0.0.1]
#     reserved:
#     - 10.0.0.2 - 10.0.0.18
#     static:
#     - 10.0.0.20
#     cloud_properties:
#       subnet: ${AWS_SUBNET_ID}
#       security_groups:
#         - ${AWS_SECURITY_GROUP}
# - name: public
#   type: vip
#
# jobs:
# - name: ScaleIO_SDC_With_RexRay
#   instances: 1
#   templates:
#   - {name: setup_sdc, release: ${SDC_RELEASE_NAME}}
#   - {name: rexray_service , release: ${REXRAY_RELEASE_NAME}}
#   resource_pool: vms
#   networks:
#   - name: private
#     static_ips: [10.0.0.20]
#     default: [dns, gateway]
#   - name: public
#     static_ips: [${AWS_ELASTIC_IP}]
#   properties:
#     network_name: private
#
# properties:
#   scaleio:
#     mdm:
#       ip: ${MDM_IP}
#   rexray: |
#     ${REXRAY_CONFIG}
#
# compilation:
#   workers: 1
#   network: private
#   reuse_compilation_vms: true
#   cloud_properties:
#     name: random
#     instance_type: m3.medium
#     availability_zone: us-east-1a
#
# update:
#   canaries: 1
#   max_in_flight: 3
#   canary_watch_time: 30000-600000
#   update_watch_time: 5000-600000
# EOF
#
# cat scaleio-acceptance-manifest.yml
#
# bosh deployment scaleio-acceptance-manifest.yml
#
# pushd scaleio-sdc-bosh-release
#   bosh -n create release --force --name $SDC_RELEASE_NAME
#   bosh -n upload release
# popd
#
# pushd rexray-bosh-release
#   bosh -n create release --force --name $REXRAY_RELEASE_NAME
#   bosh -n upload release
# popd
#
# function cleanUp {
#   bosh -n delete deployment ${SCALEIO_ACCEPTANCE_DEPLOYMENT_NAME}
#   bosh -n delete release ${REXRAY_RELEASE_NAME}
#   bosh -n delete release ${SDC_RELEASE_NAME}
# }
# trap cleanUp EXIT
#
# bosh -n deploy
#
# cat > "run_test.sh" <<EOF
#   set -x
#   export GOPATH=/home/vcap/gopath
#   export PATH=\$PATH:/home/vcap/gopath/bin
#
#   add-apt-repository ppa:ubuntu-lxc/lxd-stable && apt-get -y update && apt-get -y install golang
#   apt-get -y install git
#   mkdir -p gopath
#   go get github.com/onsi/ginkgo/ginkgo
#   go get github.com/onsi/gomega
#   go get github.com/EMC-CMD/ScaleIO-Driver-Acceptance || true
#
#   cd \$GOPATH/src/github.com/EMC-CMD/ScaleIO-Driver-Acceptance/
#   go get -t ./... || true
#
#   cd \$GOPATH/src/github.com/cloudfoundry-incubator/volman
#   go get -t ./... || true
#
#   cd \$GOPATH/src/github.com/EMC-CMD/ScaleIO-Driver-Acceptance/
#   ginkgo -r
# EOF
# chmod +x run_test.sh
#
# echo "$DEPLOYMENT_PRIVATE_KEY" > bosh.pem
# chmod 600 bosh.pem
# scp -o StrictHostKeyChecking=no -i bosh.pem run_test.sh vcap@${AWS_ELASTIC_IP}:/home/vcap/
#
# function ssh_run() {
#   ssh -o "StrictHostKeyChecking no" -i bosh.pem vcap@${AWS_ELASTIC_IP} \
#     "echo ${DEPLOYMENT_PASSWORD} | sudo -S bash -c ' $* '"
# }
#
# ssh_run ./run_test.sh
