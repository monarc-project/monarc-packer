#!/usr/bin/env bash

# Timing creation
TIME_START=$(date +%s)

# Latest version of MONARC
export MONARC_VERSION=$(curl -H 'Content-Type: application/json' https://api.github.com/repos/monarc-project/MonarcAppFO/releases/latest | jq  -r '.tag_name')
# Latest commit hash of MONARC
export LATEST_COMMIT=$(curl -H 'Content-Type: application/json' -s https://api.github.com/repos/monarc-project/MonarcAppFO/commits  | jq -r '.[0] | .sha')
# Fetching latest MONARC LICENSE
/usr/bin/wget -q -O /tmp/LICENSE-MONARC https://raw.githubusercontent.com/monarc-project/MonarcAppFO/master/LICENSE
# Enable logging for packer
PACKER_LOG=1

# Clean files from the previous build
rm -Rf output-virtualbox-iso/
rm *.checksum


packer build monarc.json


TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})
echo "The generation took ${TIME_DELTA} seconds"



#./upload.sh github_api_token=$GITHUB_AUTH_TOKEN owner=monarc-project repo=MonarcAppFO tag=$TAG filename=./output-virtualbox-iso/MONARC_demo.ova
