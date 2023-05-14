# create_vol3_symbol_files
Script for creating Volatility3 symbol files

## Usage:
~~~
./create_vol3_symbol_files.sh -d <distro> -k <kernel-version>|-a
~~~
Distros supported:
* debian
* ubuntu
* fedora
* rocky

Choose to create Volatility3 symbol files for specific kernel or all (-a).

Kernel-version:
* output of "uname -r", ex. 5.10.0-20-amd64

### Examples:

Create symbol files for Debian kernel version 5.10.0-20-amd64:
~~~
./create_vol3_symbol_files.sh -d debian -k 5.10.0-20-amd64
~~~
Create symbol files for all Debian kernels:
~~~
./create_vol3_symbol_files.sh -d debian -a
~~~
