# Build Automated Machine Images for MONARC

## Requirements

* [VirtualBox](https://www.virtualbox.org)
* [Packer](https://www.packer.io)

## Usage

    $ export GITHUB_AUTH_TOKEN=<your-github-auth-token>
    $ packer build monarc.json

A VirtualBox image will be generated.
