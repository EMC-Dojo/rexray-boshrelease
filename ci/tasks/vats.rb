#! /usr/bin/env ruby
require 'erb'
require_relative 'utils'

class VATs
  include Utils

  VATS_MANIFEST_ERB_PATH = 'rexray-boshrelease/ci/templates/vats-manifest.yml.erb'
  VATS_MANIFEST_YML_PATH = 'rexray-boshrelease/ci/templates/vats-manifest.yml'
  RUN_VATS_SH_PATH = 'rexray-boshrelease/ci/templates/run_vats.sh'
  REXRAY_CONFIG_ERB_PATH = 'rexray-boshrelease/ci/templates/rexray_config.json.erb'
  REXRAY_CONFIG_JSON_PATH = 'rexray-boshrelease/ci/templates/rexray_config.json'

  ENV_PARAMS = %W{
    BOSH_DIRECTOR_PUBLIC_IP
    BOSH_PASSWORD
    BOSH_USER
    STORAGE_SERVICE_TYPE
    VATS_DEPLOYMENT_IP
    VATS_DEPLOYMENT_NAME
    VATS_DEPLOYMENT_PASSWORD
  }

  SCALEIO_PARAMS = %W{
    SCALEIO_ENDPOINT
    SCALEIO_INSECURE
    SCALEIO_MDM_IPS
    SCALEIO_PASSWORD
    SCALEIO_STORAGE_POOL_NAME
    SCALEIO_USERNAME
    SCALEIO_VERSION
  }

  ISILON_PARAMS = %W{
    ISILON_DATA_SUBNET
    ISILON_ENDPOINT
    ISILON_INSECURE
    ISILON_PASSWORD
    ISILON_USERNAME
    ISILON_VOLUME_PATH
  }

  def initialize
    @failed = false
    check_env_params(ENV_PARAMS)
    check_env_params(SCALEIO_PARAMS) if @storage_service_type == 'scaleio'
    check_env_params(ISILON_PARAMS) if @storage_service_type == 'isilon'
  end

  def perform
    exec_cmd('apt-get -y update && apt-get install -y sshpass')
    exec_cmd('gem install bosh_cli --no-ri --no-rdoc')
    exec_cmd("bosh target #{@bosh_director_public_ip}")
    exec_cmd("bosh login #{@bosh_user} #{@bosh_password}")

    output = exec_cmd('bosh status --uuid')
    bosh_director_uuid = output[1].strip
    generate_bosh_manifest(bosh_director_uuid)

    upload_bosh_releases
    exec_cmd("bosh deployment #{VATS_MANIFEST_YML_PATH}")
    exec_cmd('bosh -n deploy')

    generate_raxray_config
    scp(REXRAY_CONFIG_JSON_PATH)
    scp(RUN_VATS_SH_PATH)
    ssh_run_vats
  ensure
    # exec_cmd("bosh -n delete deployment #{@vats_deployment_name}")
    # exec_cmd("bosh -n delete release rexray-boshrelease")
    # exec_cmd("bosh -n delete release scaleio-sdc-boshrelease")
  end

  def scp(filepath)
    exec_cmd("sshpass -p #{@vats_deployment_password} \
              scp -o StrictHostKeyChecking=no #{filepath} \
              vcap@#{@vats_deployment_ip}:/home/vcap/")
  end

  def ssh_run_vats
    exec_cmd("sshpass -p #{@vats_deployment_password} \
              ssh -o StrictHostKeyChecking=no vcap@#{@vats_deployment_ip} \
              \"echo #{@vats_deployment_password} | sudo -S bash -c '/home/vcap/run_vats.sh'\"")
  end

  def upload_bosh_releases
    exec_cmd("pushd rexray-boshrelease && \
              bosh -n create release --force --name rexray-boshrelease && \
              bosh -n upload release && \
              popd")

    if @storage_service_type == 'scaleio'
      exec_cmd("pushd scaleio-sdc-boshrelease && \
                bosh -n create release --force --name scaleio-sdc-boshrelease && \
                bosh -n upload release && \
                popd")
    end
  end

  def generate_bosh_manifest(bosh_director_uuid)
    results = ERB.new(File.read(VATS_MANIFEST_ERB_PATH)).result(binding())
    File.open(VATS_MANIFEST_YML_PATH, 'w+') do |f|
      f.write(results)
    end
  end

  def generate_raxray_config
    results = ERB.new(File.read(REXRAY_CONFIG_ERB_PATH)).result(binding())
    File.open(REXRAY_CONFIG_JSON_PATH, 'w+') do |f|
      f.write(results)
    end
  end

  if __FILE__ == $0
    VATs.new.perform
  end
end
