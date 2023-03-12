#!/bin/bash
# Ensure we fail if variables are not set/populated.
# Removes the danger for doing an "rm -rf" for: ${SOME_VARIABLE}/*
set -o errexit
set -o nounset
set -o pipefail

SCRIPTNAME=$0
ARGUMENT=$1
SCRIPTDIR=$( readlink -f ${SCRIPTNAME} | awk -F $( basename ${SCRIPTNAME} ) '{print $1}' )
DOWNLOAD_SITE=''
TEMP_DIR='/tmp/symbol_workdir'
SYMBOL_DIR="${HOME}/volatility_symbol_files"
DISTRO=''

_sanity_checks() {
    if [ ! -d ${TEMP_DIR} ]; then
        mkdir ${TEMP_DIR}
        mkdir ${TEMP_DIR}/temp_kernel
    fi

    if [ ! -d ${SYMBOL_DIR} ]; then
        mkdir ${SYMBOL_DIR}
    fi

    if [ $( which ar | echo $? ) -eq 1 ) ]; then
        echo '"ar" command missing and needs to be installed for script to work.'
        echo 'For DEB-based systems - install the "binutils" package. Run: sudo apt -y install binutils'
        echo 'For RPM-based systems - install the "unar" package. Run: sudo yum -y install unar'
        echo 'Then rerun script.'
        exit 1
    fi

    if [ $( which unxz | echo $? ) -eq 1 ]; then
        echo '"unxz" command missing and needs to be installed for script to work.'
        echo 'For DEB-based systems - install the "xz-utils" package. Run: sudo apt -y install xz-utils'
        echo 'For RPM-based systems - install the "xz" package. Run: sudo yum -y install xz'
        echo 'Then rerun script.'
        exit 1
    fi

    if [ $( which rpm2cpio | echo $? ) -eq 1 ]; then
        echo '"rpm2cpio" command missing and needs to be installed for script to work.'
        echo 'For DEB-based systems - install the "rpm2cpio" package. Run: sudo apt -y install rpm2cpio'
        echo 'For RPM-based systems - re-install the "rpm" package. Run: sudo yum -y install rpm'
        echo 'Then rerun script.'
        exit 1
    fi
}

_get_download_page() {
    wget ${DOWNLOAD_SITE} -O ${TEMP_DIR}/index.html
}

_clean_temp_kernel() {
    rm -rf ${TEMP_DIR}/temp_kernel
    mkdir ${TEMP_DIR}/temp_kernel
}

_distrocheck() {
    DIST=$1
    case ${DIST} in
        debian)
            DOWNLOAD_SITE='http://ftp.dk.debian.org/debian/pool/main/l/linux/'
            DISTRO='debian'
            ;;
        ubuntu)
            DOWNLOAD_SITE='http://ddebs.ubuntu.com/ubuntu/pool/main/l/'
            DISTRO='ubuntu'
            ;;
        fedora)
            DOWNLOAD_SITE='https://copr.fedorainfracloud.org/coprs/g/kernel-vanilla/fedora/'
            DISTRO='fedora'
            ;;
        *)
            echo "${DIST} is unknown/not supported - bug-report with links to package repo etc."
            exit 1
            ;;
    esac
}

_ensure_distro_symbol_file_dir() {
    # Ensure Distro has been provided on command-line
    if [ ! ${DISTRO} ]; then
        echo 'You need to provide name of distro for which you want symbol-file(s) created.'
        _show_usage
    fi
    # Ensure directory for Distro in symbol-files directory
    if [ ! -d ${SYMBOL_DIR}/${DISTRO} ]; then
        mkdir ${SYMBOL_DIR}/${DISTRO}
    fi
}

_show_usage() {
    echo 'Usage for creating symbol files:'
    echo "${PROGRAMNAME} [-d <distro>] [-k <kernel-version>]|[-a]"
    echo 'kernel-version = output of "uname -r" ex. 5.10.0-20-amd64'
    echo '-d <distro>           - Distro: debian, ubuntu, fedora'
    echo '-k <kernel-version>   - Creating symbol file for kernel version given if it exists'
    echo '-a                    - Create symbol files for all kernel versions'
    exit 1
}

##################
## MAIN PROGRAM ##
##################
_sanity_checks
while getopts "d:k:a" ARGUMENT; do
    case "${ARGUMENT}" in
        d)
            # Distro for which symbol-file will be created
            if [ ! ${OPTARG} ]; then
                echo 'You need to provide distro-name for which you want symbol-file created.'
                _show_usage
            fi
            _distrocheck ${OPTARG}
            source ${SCRIPTDIR}/${DISTRO}.sh
            ;;
        k)
            # Create symbol-file for specific kernel
            if [ ! ${OPTARG} ]; then
                echo 'You need to provide kernel for which you want symbol-file created.'
                _show_usage
            fi
            _ensure_distro_symbol_file_dir
            _get_download_page
            _single_kernel ${OPTARG}
            ;;
        a)
            # Create symbol-files for ALL kernel versions
            _ensure_distro_symbol_file_dir
            _get_download_page
            _all_kernels
            ;;
        *)
            # If nothing or anything else is used, show usage
            _show_usage
            ;;
    esac
done
