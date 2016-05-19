###RexRay Bosh Release

REX-Ray delivers persistent storage access for container runtimes, such as Docker and Mesos, and provides an easy interface for enabling advanced storage functionality across common storage, virtualization and cloud platforms. 

This Bosh release only contains the RexRay Release Binary version 0.3, which is required to be placed in the client VM in order to access volumes hosted on any storage platform.

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
  
```

For more examples of information about using other storage providers, please see <http://rexray.readthedocs.org/>

###Contact
- For questions on using the Bosh release:
	- Email: [EMCdojo@emc.com](mailto:EMCdojo@emc.com) 
	- Twitter: [@EMCDojo](https://twitter.com/hashtag/emcdojo)
	- Blog: [EMC Dojo Blog](dojoblog.emc.com)

- For questions on using RexRay:
	- Slack Channel:
  		- Organization: <http://codecommunity.slack.com>
  		- Channel: `#project-rexray`
  
	- Github: <https://github.com/emccode/rexray>

 
 
 
 

 
