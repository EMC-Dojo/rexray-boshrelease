set -x

add-apt-repository -y ppa:ubuntu-lxc/lxd-stable
apt-get -y update

#install golang
wget https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz --no-check-certificate
sudo tar -xvf go1.7.linux-amd64.tar.gz
sudo chmod 777 -R go
sudo mv go /usr/local
export GOROOT=/usr/local/go

apt-get -y install git

mkdir -p gocode
export GOPATH=/home/vcap/gocode
export PATH=$PATH:$GOPATH/bin:$GOROOT/bin

go get --insecure -f -u code.cloudfoundry.org/cfhttp
go get --insecure -f -u code.cloudfoundry.org/cfhttp/handlers
go get --insecure -f -u code.cloudfoundry.org/clock
go get --insecure -f -u code.cloudfoundry.org/lager
go get --insecure -f -u code.cloudfoundry.org/lager/lagertest
go get --insecure -f -u code.cloudfoundry.org/voldriver
go get --insecure -f -u code.cloudfoundry.org/voldriver/driverhttp
go get --insecure -f -u github.com/onsi/ginkgo/ginkgo
go get --insecure -f -u github.com/onsi/gomega
go get --insecure -f -u github.com/tedsuo/ifrit
go get --insecure -f -u github.com/tedsuo/ifrit/ginkgomon
go get --insecure -f -u gopkg.in/yaml.v2

cd $GOPATH/src/code.cloudfoundry.org
git clone https://github.com/EMC-Dojo/volume_driver_cert
cd volume_driver_cert

export FIXTURE_FILENAME=/home/vcap/rexray_config.json
ginkgo -r
