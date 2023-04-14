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

# Enable logging for packer, launch the generation of the virtual machine
echo "Generating a virtual machine for MONARC $MONARC_VERSION (commit id: $LATEST_COMMIT)…"
PACKER_LOG=1 packer build -only=virtualbox-iso monarc.json

TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})
echo "The generation took ${TIME_DELTA} seconds."

echo "Generation of the release bundle (.tar.gz file)…"
TIME_START=$(date +%s)
bundle=MONARC_$MONARC_VERSION@${LATEST_COMMIT:0:7}
mkdir $bundle
mv packer_virtualbox-iso_virtualbox-iso_sha1.checksum $bundle/SHA1SUMS
mv packer_virtualbox-iso_virtualbox-iso_sha512.checksum $bundle/SHA512SUMS
mv output-virtualbox-iso/MONARC_$MONARC_VERSION@$LATEST_COMMIT.ova $bundle
cat > $bundle/README <<EOF
# Login and Password for MONARC App (format: username:password)

 MONARC application: admin@admin.localhost:admin

# Login and Password for VirtualBox demo image (format: username:password)

SSH login (Ubuntu credentials): monarc:password

# Database:

- Mysql root login: root:a7daab4243ed998c7e61dc6e4aa48f64dda354021778379ec11e75430534693e
- Mysql MONARC login: sqlmonarcuser:8c125ed24f4cf1fe50ec8ac4450c81c98b65475677956242bb9385e97fa4027d


MONARC is available on port 80.

MONARC Stats Service is available on port 5005.
EOF
tar -czvf MONARC_$MONARC_VERSION@$LATEST_COMMIT.tar.gz $bundle
TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})
echo "The generation took ${TIME_DELTA} seconds."

# Cleaning…
rm -Rf $bundle output-virtualbox-iso/ 2> /dev/null

# Upload the generated bundle
# read -r -p "Do you want to upload the generated bundle? [y/N] " response
# case "$response" in
#     [yY][eE][sS]|[yY])
#         scp MONARC_$MONARC_VERSION@$LATEST_COMMIT.tar.gz vm.monarc.lu
#         ;;
#     *)
#         :
#         ;;
# esac

echo "Good bye."
exit 0
