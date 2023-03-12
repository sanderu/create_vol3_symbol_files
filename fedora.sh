#!/bin/bash
# Creates the symbol-file(s) for Fedora kernel(s)

_handle_rpm() {
    KERN_VAR=$1
    FULL_NAME=$2

    if [ ! -d ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR} ]; then
        mkdir ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}
    fi

    # Skip creating symbol-file if we already have it
    if [ -f ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${KERN_VAR}.json.xz ]; then
        return
    fi

    # Get linux-image file
    wget ${DOWNLOAD_SITE}/${FULL_NAME} -O ${TEMP_DIR}/${FULL_NAME}

    # Ensure we have clean environment, unpack kernel-deb package, extract necessary files and create symbol-file
    _clean_temp_kernel
    rpm2cpio ${TEMP_DIR}/${FULL_NAME} | cpio -dium -D ${TEMP_DIR}/temp_kernel

    HAS_SYSTEM_MAP=$( find ${TEMP_DIR}/temp_kernel/ -type f -name System.map )
    HAS_VMLINUX=$( find ${TEMP_DIR}/temp_kernel/ -type f -name vmlinux )

    cd ${TEMP_DIR}/temp_kernel
    if [ x${HAS_SYSTEM_MAP} == 'x' ]; then
        cd ${TEMP_DIR}
        ${SCRIPTDIR}/dwarf2json linux --elf ${HAS_VMLINUX} | tee > ${TEMP_DIR}/${KERN_VAR}.json
    else
        cd ${TEMP_DIR}
        ${SCRIPTDIR}/dwarf2json linux --system-map ${HAS_SYSTEM_MAP} --elf ${HAS_VMLINUX} | tee > ${TEMP_DIR}/${KERN_VAR}.json
    fi

        # Create banner.txt file
        grep -A15 linux_banner ${TEMP_DIR}/${KERN_VAR}.json | grep constant_data | awk -F '"' '{print $4}' | base64 -d > ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/banner.txt
        xz ${TEMP_DIR}/${KERN_VAR}.json
        mv ${TEMP_DIR}/${KERN_VAR}.json.xz ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${KERN_VAR}.json.xz
        rm ${TEMP_DIR}/${FULL_NAME}
    else
        echo "Unable to create symbol-file as data.tar.xz is missing after unpacking: ${FULL_NAME}"
        exit 1
    fi
}

_single_kernel() {
    # Create symbol-file based on provided kernel version
    KERN_VAR=$1
    KERN_ARCH=$( echo ${KERN_VAR} | awk -F '.' '{print $NF}' )
    DISTRO_VERS=$( echo ${KERN_VAR} | awk -F '.' '{print $(NF-1)}' | sed -e 's/fc/fedora-' )
    KERN_NAME=$( echo ${KERN_VAR} | awk -F '.' '{print "kernel-debuginfo-"$1"."$2"."$3".vanilla."$4"."$5".rpm"}' )

    for KERNS in $( wget ${DOWNLOAD_SITE}/${DISTRO_VERS}/${KERN_ARCH} -O - | grep "summary='Directory Listing'" | sed -e 's/<a/\n/g' | grep stable-fedora-releases | awk -F "href='" '{print $2}' | awk -F "'" '{print $1}' ); do
        for RPM in $( wget ${DOWNLOAD_SITE}/${DISTRO_VERS}/${KERN_ARCH}/${KERNS} -O - | sed -e 's/<a/\n/g'| grep debuginfo | awk -F "href='" '{print $2}' | awk -F "'" '{print $1}' ); do
            if [ x${RPM} == x"${KERN_NAME}" ]; then
                FULL_NAME="${DISTRO_VERS}/${KERN_ARCH}/${KERNS}/${RPM}"
                _handle_rpm ${KERN_VAR} ${FULL_NAME}
            fi
        done
    done
    echo "Finished creating symbol-file for ${KERN_VAR}."
    exit 0
}

_all_kernels() {
    # Create symbol-files for all kernels
    for TEMP_NAME in $( grep '</span>     Fedora ' ${TEMP_DIR}/index.html | awk -F '</span>     ' '{print $2}' | sed -e 's/ /-/g' | tr '\n' ' ' ); do
        for VERSION in ${TEMP_NAME}; do
            for ARCH in aarch64 ppc64le x86_64; do
                for RESULT in $( wget ${TEMP_NAME}/${VERSION}-${ARCH} -O - | grep "summary='Directory Listing'" | sed -e 's/<a/\n/g' | grep stable-fedora-releases | awk -F "href='" '{print $2}' | awk -F "'" '{print $1}' ); do
                    if [  ! ${RESULT} ]; then
                        break
                    fi

                    for KERN in $( wget ${TEMP_NAME}/${VERSION}-${ARCH}/${RESULT} -O - | sed -e 's/<a/\n/g'| grep debuginfo | awk -F "href='" '{print $2}' | awk -F "'" '{print $1}' ); do
                        FULL_NAME="${TEMP_NAME}/${VERSION}-${ARCH}/${RESULT}/${KERN}"
                        KERN_VAR=$( echo ${KERN} | awk -F 'kernel-debuginfo-' '{print $2}' | awk -F '.' '{print $1"."$2"."$3"."$5"."$6}' )
                        _handle_rpm ${KERN_VAR} ${FULL_NAME}
                    done
                done
            done
        done
    done
    echo 'Finished creating symbol-files for all kernels.'
    exit 0
}
