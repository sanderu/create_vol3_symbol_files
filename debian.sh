#!/bin/bash
# Creates the symbol-file(s) for Debian kernel(s)

_handle_deb() {
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
    ar x ${TEMP_DIR}/${FULL_NAME} --output ${TEMP_DIR}/temp_kernel
    cd ${TEMP_DIR}/temp_kernel
    if [ -f data.tar.xz ]; then
        unxz data.tar.xz

        if [ $( tar -tf data.tar | grep System.map ) ]; then
            tar --wildcards -x ./usr/lib/debug/boot/System.map-${KERN_VAR} -f data.tar
            tar --wildcards -x ./usr/lib/debug/boot/vmlinux-${KERN_VAR} -f data.tar
            cd ${TEMP_DIR}
            ${SCRIPTDIR}/dwarf2json linux --system-map ${TEMP_DIR}/temp_kernel/usr/lib/debug/boot/System.map-${KERN_VAR} --elf ${TEMP_DIR}/temp_kernel/usr/lib/debug/boot/vmlinux-${KERN_VAR} | tee > ${TEMP_DIR}/${KERN_VAR}.json
        else
            tar --wildcards -x ./usr/lib/debug/boot/vmlinux-${KERN_VAR} -f data.tar
            cd ${TEMP_DIR}
            ${SCRIPTDIR}/dwarf2json linux --elf ${TEMP_DIR}/temp_kernel/usr/lib/debug/boot/vmlinux-${KERN_VAR} | tee > ${TEMP_DIR}/${KERN_VAR}.json
        fi
        
        # Create banner.txt file
        grep -A15 linux_banner ${TEMP_DIR}/${KERN_VAR}.json | grep constant_data | awk -F '"' '{print $4}' | base64 -d > ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/banner.txt
        xz ${TEMP_DIR}/${KERN_VAR}.json 
        mv ${TEMP_DIR}/${KERN_VAR}.json.xz ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${KERN_VAR}.json.xz
    else
        echo "Unable to create symbol-file as data.tar.xz is missing after unpacking: ${FULL_NAME}"
        exit 1
    fi
}

_single_kernel() {
    # Create symbol-file based on provided kernel version
    KERN_VAR=$1
    MATCH=$( grep '<a href="linux-image-'${KERN_VAR}'-dbg_'".*"'.deb" title=' ${TEMP_DIR}/index.html )
    if [ ! ${MATCH} ]; then
        echo "Didn't find: ${KERN_VAR} link at download site. Exiting."
        exit 1
    else
        echo "Found: ${KERN_VAR} link from download site."
        FULL_NAME=$( echo ${MATCH} | awk -F '<a href="' '{print $2}' | cut -f1 -d '"' )
        _handle_deb ${KERN_VAR} ${FULL_NAME}
    fi
    echo "Finished creating symbol-file for ${KERN_VAR}."
    exit 0
}

_all_kernels() {
    # Create symbol-files for all kernels
    for FULL_NAME in $( grep 'linux-image-' ${TEMP_DIR}/index.html | grep '\-dbg_' | awk -F '<a href="' '{print $2}' | awk -F '" title="linux-image' '{print $1}' | grep -E 'linux-image-[0-9]\.[0-9]' ); do 
        KERN_VAR=$( echo ${FULL_NAME} | awk -F 'linux-image-' '{print $2}' | awk -F '-dbg_' '{print $1}' )
        _handle_deb ${KERN_VAR} ${FULL_NAME}
    done
}