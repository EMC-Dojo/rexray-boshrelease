# :hurtrealbad: :rage1: DEPRECATED :rage2: :rage3:
This BOSH release is no longer actively maintained.  If you are using shared NFS volumes with Cloud Foundry, we recommend using [nfs-volume-release](https://github.com/cloudfoundry-incubator/nfs-volume-release).  If that broker/volume driver does not meet your needs, please let us know by posting an issue or pull request to that Github repository.

###RexRay Bosh Release

REX-Ray delivers persistent storage access for container runtimes, such as Docker and Mesos, and provides an easy interface for enabling advanced storage functionality across common storage, virtualization and cloud platforms. 

This Bosh release only contains the RexRay Release Binary version 0.4, which is required to be placed in the client VM in order to access volumes hosted on any storage platform.

###Creating Bosh Release
 
 1. Obtain code from Github: 
 2. Go into the directory: 
 3. Create Bosh Release
 
 ```
 git clone https://github.com/EMC-CMD/rexray-boshrelease.git
 cd rexray-boshrelease
 bosh create release
 ```
###Uploading Bosh Release
 1. Upload Bosh Release
 
 ``` bosh upload release ```
 
###Configuring RexRay with a BOSH Manifest
In order to run RexRay, it requires a Configuration YMl. Since we are deploying RexRay through BOSH, this YML must go into the deployment manifest underneath the properties section. Below is an example of using this release with ScaleIO (This required the ScaleIO SDC Release as well)

```
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
      spec: /var/vcap/data/voldrivers/rexray.spec 
      type: docker
  storageDrivers:
  - scaleio
scaleio:
  endpoint: https://*.*.*.*/api
  insecure: false
  userName: admin
  password: password
  protectionDomainID: 4c9e0aa100000000
  protectionDomainName: default    
  storagePoolName: default    
  storagepoolID: 1234567800000000
  systemID: 5c4c45f02c98552e
  systemName: system
  thinOrThick: ThinProvisioned
  useCerts: true
linux:
  volume:
    fileMode: 0777  
```

For more examples of information about using other storage providers, please see <http://rexray.readthedocs.org/>

###Using RexRay for EMC Persistence with CloudFoundry (Diego Release)
In order to use EMC storage with CloudFoundry you will need to deploy Diego cells (also with BOSH) where your applications will then live. 

When deploying Deigo cells the volume manager needs to understand where the volume driver (RexRay) lives. You have two options for configuring this.

-  Change the `default-docker.spec` line in the rexray config above to `/var/vcap/data/voldrivers/rexray.spec`
-  Add `/etc/docker/plugins/rexray.spec` or your specific `*.spec` file for your volume driver to `properties.diego.executor.volman.driver_paths` in your Diego manifest.  
  
###Contact
- For questions on using the Bosh release:
	- Email: [EMCdojo@emc.com](mailto:EMCdojo@emc.com) 
	- Twitter: [@EMCDojo](https://twitter.com/hashtag/emcdojo)
	- Blog: [EMC Dojo Blog](dojoblog.emc.com)
	- Slack Channel:
  		- Organization: <http://codecommunity.slack.com>
  		- Channel: `#project-rexray`
  
	- Github: <https://github.com/emccode/rexray>

 
 
 
 

 
