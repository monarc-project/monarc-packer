#!/usr/bin/env bash

# Timing creation
TIME_START=$(date +%s)

# Latest version of MONARC
echo "Retrieving information about latest MONARC release…"
export MONARC_VERSION=$(curl --silent -H 'Content-Type: application/json' https://api.github.com/repos/monarc-project/MonarcAppFO/releases/latest | jq  -r '.tag_name')
# Latest commit hash of MONARC
export LATEST_COMMIT=$(curl --silent -H 'Content-Type: application/json' -s https://api.github.com/repos/monarc-project/MonarcAppFO/commits | jq -e -r '.[0] | .sha')

# Fetching latest MONARC LICENSE
wget -q -O /tmp/LICENSE-MONARC https://raw.githubusercontent.com/monarc-project/MonarcAppFO/master/LICENSE
# Enable logging for packer
PACKER_LOG=1

# Clean files from the previous build
rm -Rf output-virtualbox-iso/  2> /dev/null
rm *.checksum  2> /dev/null

# Launch the generation of the virtual machine
echo "Generating a virtual machine for MONARC $MONARC_VERSION (commit id: $LATEST_COMMIT)…"
packer build monarc.json

TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})
echo "The generation took ${TIME_DELTA} seconds"

echo "Generation of the release bundle…"
mv packer_virtualbox-iso_virtualbox-iso_sha1.checksum SHA1SUMS
mv packer_virtualbox-iso_virtualbox-iso_sha512.checksum SHA512SUMS

tar -czvf MONARC_$MONARC_VERSION@$LATEST_COMMIT.tar.gz SHA1SUMS SHA512SUMS output-virtualbox-iso/MONARC_$MONARC_VERSION@$LATEST_COMMIT.ova 
echo "Bundle generated."

# Upload the generated virtual machine
# read -r -p "Do you want to upload the generated virtual machine on GitHub? [y/N] " response
# case "$response" in
#     [yY][eE][sS]|[yY])
#         ./upload.sh github_api_token=$GITHUB_AUTH_TOKEN owner=monarc-project repo=MonarcAppFO tag=$MONARC_VERSION filename=output-virtualbox-iso/MONARC_$MONARC_VERSION_$LATEST_COMMIT.ova
#         ;;
#     *)
#         :
#         ;;
# esac

echo "Good bye."
exit 0
