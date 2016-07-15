#!/usr/bin/env bash

set -e -x

source rexray-bosh-release/ci/tasks/utils.sh

check_param GITHUB_USER
check_param GITHUB_EMAIL
check_param S3_ACCESS_KEY_ID
check_param S3_SECRET_ACCESS_KEY
check_param REXRAY_RELEASE_NAME

# Creates an integer version number from the semantic version format
# May be changed when we decide to fully use semantic versions for releases
integer_version=`cut -d "." -f1 rexray-release-version-semver/number`
echo ${integer_version} > promote/integer_version

cp -r rexray-bosh-release promote/rexray-bosh-release
pushd promote/rexray-bosh-release
  set +x
  echo creating config/private.yml with blobstore secrets
  cat > config/private.yml <<EOF
---
blobstore:
  s3:
    bucket_name: rexray-bosh-release
    access_key_id: ${S3_ACCESS_KEY_ID}
    secret_access_key: ${S3_SECRET_ACCESS_KEY}
EOF
  set -x

  echo "using bosh CLI version..."
  bosh version

  echo "finalizing rexray release..."
  echo '' | bosh create release --force --with-tarball --version ${integer_version} --name ${REXRAY_RELEASE_NAME}
  bosh finalize release dev_releases/${REXRAY_RELEASE_NAME}/*.tgz --version ${integer_version}

  rm config/private.yml

  git diff | cat
  git add .

  git config --global user.email ${GITHUB_EMAIL}
  git config --global user.name ${GITHUB_USER}
  git config --global push.default simple

  git commit -m ":airplane: New final release v ${integer_version} [ci skip]"

popd
