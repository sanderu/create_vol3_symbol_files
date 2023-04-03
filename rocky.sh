#!/bin/bash
# Creates the symbol-file(s) for Rocky Linux kernel(s)

_handle_rpm() {
    KERN_VAR=$1
    FULL_NAME=$2
    PKG_NAME=$( echo ${FULL_NAME} | awk -F '/' '{print $NF}' )

    if [ ! -d ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR} ]; then
        mkdir ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}
    fi

    # Skip creating symbol-file if we already have it
    if [ -f ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${KERN_VAR}.json.xz ]; then
        return
    fi

    # Get linux-image file
    wget ${DOWNLOAD_SITE}/${FULL_NAME} -O ${TEMP_DIR}/${PKG_NAME}

    # Ensure we have clean environment
    _clean_temp_kernel
    
    # Unpack kernel package
    rpm2cpio ${TEMP_DIR}/${PKG_NAME} | cpio -dium -D ${TEMP_DIR}/temp_kernel

    # Extract necessary files
    HAS_SYSTEM_MAP=$( find ${TEMP_DIR}/temp_kernel/ -type f -name System.map )
    HAS_VMLINUX=$( find ${TEMP_DIR}/temp_kernel/ -type f -name vmlinux )

    # Create symbol-file
    cd ${TEMP_DIR}/temp_kernel
    if [ ! -z ${HAS_SYSTEM_MAP} ]; then
        if [ ! -z ${HAS_VMLINUX} ]; then
            cd ${TEMP_DIR}
            ${SCRIPTDIR}/dwarf2json linux --system-map ${HAS_SYSTEM_MAP} --elf ${HAS_VMLINUX} | tee > ${TEMP_DIR}/${KERN_VAR}.json
        else
            cd ${TEMP_DIR}
            ${SCRIPTDIR}/dwarf2json linux --system-map ${HAS_SYSTEM_MAP} | tee > ${TEMP_DIR}/${KERN_VAR}.json
        fi
    elif [ ! -z ${HAS_VMLINUX} ]; then
        cd ${TEMP_DIR}
        ${SCRIPTDIR}/dwarf2json linux --elf ${HAS_VMLINUX} | tee > ${TEMP_DIR}/${KERN_VAR}.json
    else
        echo 'Unable to create symbol-file as both System.map and vmlinux is missing in debug kernel-package'
        exit 1
    fi

    # Create banner.txt file - NOPE! not for Rocky Linux - constant_data not present in json file
    xz ${TEMP_DIR}/${KERN_VAR}.json
    mv ${TEMP_DIR}/${KERN_VAR}.json.xz ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${KERN_VAR}.json.xz
    rm ${TEMP_DIR}/${PKG_NAME}
}

_single_kernel() {
    # Create symbol-file based on provided kernel version
    KERN_VAR=$1
    KERN_ARCH=$( echo ${KERN_VAR} | awk -F '.' '{print $NF}' )
    CHECK_DISTRO_VERS=$( echo ${KERN_VAR} | awk -F '.' '{print $(NF-1)}' | sed -e 's/el//' )
    if [ ! -z $( grep '_' ${CHECK_DISTRO_VERS} ) ]; then
        DISTRO_VERS=$( echo ${CHECK_DISTRO_VERS} | sed -e 's/_/\./' )
    else
        DISTRO_VERS=${CHECK_DISTRO_VERS}
    fi
    KERN_NAME=$( echo 'kernel-debug-core-'${KERN_VAR}'.rpm' )
    for DL_SITE in ${DOWNLOAD_SITE} https://dl.rockylinux.org/vault/rocky/ ; do
        if [ ! $( wget ${DL_SITE}/${VERSION}/BaseOS/${ARCH}/os/Packages/k -O ${TEMP_DIR}/index3.html ) ]; then
            FULL_NAME="${DISTRO_VERS}/BaseOS/${KERN_ARCH}/os/Packages/${KERN_NAME}"
        else
            FULL_NAME="${DISTRO_VERS}/BaseOS/${KERN_ARCH}/os/Packages/k/${KERN_NAME}"
        fi
    done
    DOWNLOAD_SITE=${DL_SITE}
    _handle_rpm ${KERN_VAR} ${FULL_NAME}

    echo "Finished creating symbol-file for ${KERN_VAR}."
    exit 0
}

_all_kernels() {
    # DOWNLOAD_SITE
    # https://dl.rockylinux.org/vault/rocky/9.0/BaseOS/
    # Create symbol-files for all kernels
    for DL_SITE in ${DOWNLOAD_SITE} https://dl.rockylinux.org/vault/rocky/ ; do
        for VERSION in $( grep ' -' ${TEMP_DIR}/index.html | awk -F 'href="' '{print $2}' | awk -F '/">' '{print $1}' | sed -e 's/ /-/g' | tr '\n' ' ' ); do
            for ARCH in $( wget ${DL_SITE}/${VERSION}/BaseOS -O - | grep ' -' | grep -v 'source' | awk -F 'href="' '{print $2}' | awk -F '/">' '{print $1}' | tr '\n' ' ' ); do
                # https://download.rockylinux.org/pub/rocky/9.1/BaseOS/ppc64le/os/Packages/k
                PKG_URL='Packages/k'
                if [ ! $( wget ${DL_SITE}/${VERSION}/BaseOS/${ARCH}/os/${PKG_URL} -O ${TEMP_DIR}/index2.html ) ]; then
                    PKG_URL='Packages'
                    wget ${DL_SITE}/${VERSION}/BaseOS/${ARCH}/os/${PKG_URL} -O ${TEMP_DIR}/index2.html
                fi
                if [[ -z $( cat /tmp/index2.html ) ]]; then
                    break
                fi
                for KERN in $( grep 'kernel-debug-core-' /tmp/index2.html | awk -F 'href="' '{print $2}' | awk -F '">kernel-debug-core-' '{print $1}' ); do
                    FULL_NAME="${VERSION}/BaseOS/${ARCH}/os/${PKG_URL}/${KERN}"
                    KERN_VAR=$( echo ${KERN} | awk -F 'kernel-debug-core-' '{print $2}' | awk -F '.rpm' '{print $1}' )
                    DOWNLOAD_SITE=${DL_SITE}
                    _handle_rpm ${KERN_VAR} ${FULL_NAME}
                done
            done
        done
    done
    echo 'Finished creating symbol-files for all kernels.'
    exit 0
}
