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

- create a new release: https://developer.github.com/v3/repos/releases/#create-a-release
- upload a release asset: https://developer.github.com/v3/repos/releases/#upload-a-release-asset

Example of a binary upload with curl (from the GitHub blog):

    curl -H "Authorization: token <yours>" \
     -H "Accept: application/vnd.github.manifold-preview" \
     -H "Content-Type: application/zip" \
     --data-binary @build/mac/package.zip \
     "https://uploads.github.com/repos/hubot/singularity/releases/123/assets?name=1.0.0-mac.zip"
