# Build Automated Machine Images for MONARC

## Requirements

* [VirtualBox](https://www.virtualbox.org);
* [Packer](https://www.packer.io) from the Packer website;
* [jq](https://github.com/stedolan/jq);
* [tar](https://savannah.gnu.org/projects/tar).

## Usage

    $ ./build_vm.sh
    Retrieving information about latest MONARC release…
    Generating a virtual machine for MONARC v2.11.0-p1 (commit id: 89dc30523dd10bd01f12320b36f3762a50582c23)…
    The generation took 773 seconds.
    Generation of the release bundle…
    The generation took 61 seconds.
    Bundle generated.
    Do you want to upload the generated bundle? [y/N] n
    Good bye.

A VirtualBox image will be generated and bundled in a tar.gz file with other
assets.

Default credentials (Web interface, SSH and MariaDB) are displayed at the end
of the process.

