# Build Automated Machine Images for MONARC

## Requirements

* [VirtualBox](https://www.virtualbox.org);
* [Packer](https://www.packer.io) from the Packer website;
* [jq](https://github.com/stedolan/jq);
* [tar](https://savannah.gnu.org/projects/tar).

## Usage

Execute the shell script:

    $ ./build_vm.sh

Caution: The generated encrypted password is created with use of the following command:
    $ echo 'Password@1234!' | mkpasswd -m sha-512 --stdin
NOTE: mkpasswd part of whois package in Ubuntu:

A VirtualBox image will be generated and bundled in a tar.gz file with other
assets.

Default credentials (Web interface, SSH and MariaDB) are displayed at the end
of the process.

