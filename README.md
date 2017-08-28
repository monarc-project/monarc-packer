# Build Automated Machine Images for MONARC

## Requirements

* [VirtualBox](https://www.virtualbox.org)
* [Packer](https://www.packer.io)

## Usage

    $ export GITHUB_AUTH_TOKEN=<your-github-auth-token>
    $ packer build monarc.json

A VirtualBox image will be generated and stored in the folder
*output-virtualbox-iso*. You can directly import it in VirtualBox.

### Automatic export to GitHub

    $ GITHUB_AUTH_TOKEN=<your-github-auth-token>
    $ TAG=$(curl https://api.github.com/repos/monarc-project/MonarcAppFO/releases/latest | jq  -r '.tag_name')
    $ ./upload.sh github_api_token=$GITHUB_AUTH_TOKEN owner=monarc-project repo=MonarcAppFO tag=$TAG filename=./output-virtualbox-iso/MONARC_demo.ova
