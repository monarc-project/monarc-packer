# Build Automated Machine Images for MONARC

## Requirements

* [VirtualBox](https://www.virtualbox.org);
* [Packer](https://www.packer.io) from the Packer website;
* [jq](https://github.com/stedolan/jq).

## Usage

    $ ./build_vm.sh
    Retrieving information about latest MONARC release...
    Generating a virtual machine for MONARC v2.7.2 (commit id: 99e80ba03cfba2e270473b42b4fb53dec1d2b8b0)...
    The generation took 773 seconds.
    Generation of the release bundle…
    The generation took 61 seconds.
    Bundle generated.
    Do you want to upload the generated bundle? [y/N] n
    Good bye.

A VirtualBox image will be generated and stored in the folder
*output-virtualbox-iso*. You can directly import it in VirtualBox.

Default credentials (Web interface, SSH and MariaDB) are displayed at the end
of the process.

