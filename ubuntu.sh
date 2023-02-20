#!/bin/bash
# Creates the symbol-file(s) for Ubuntu kernel(s)

# Ubuntu files
# loop over : 'linux-', 'linux-aws', 'linux-azure', 'linux-gcp'
# linux:        http://ddebs.ubuntu.com/ubuntu/pool/main/l/linux/
# linux-aws:    http://ddebs.ubuntu.com/ubuntu/pool/main/l/linux-aws/
# linux-azure:  http://ddebs.ubuntu.com/ubuntu/pool/main/l/linux-azure/
# linux-gcp:    http://ddebs.ubuntu.com/ubuntu/pool/main/l/linux-gcp/

_handle_deb() {
    KERN_VAR=$1
    FULL_NAME=$2
    ARCH=$3
    BRANCH=$4

    if [ ! -d ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR} ]; then
        mkdir -p ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}
    fi

    # Skip creating symbol-file if we already have it
    if [ -f ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${KERN_VAR}_${ARCH}.json.xz ]; then
        return
    fi

    # Get linux-image file
    wget -U "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)" ${DOWNLOAD_SITE}/${BRANCH}/${FULL_NAME} -O ${TEMP_DIR}/${FULL_NAME}

    # Ensure we have clean environment, unpack kernel-deb package, extract necessary files and create symbol-file
    _clean_temp_kernel
    ar x ${TEMP_DIR}/${FULL_NAME} --output ${TEMP_DIR}/temp_kernel
    cd ${TEMP_DIR}/temp_kernel
    if [ -f data.tar.xz ]; then
        unxz data.tar.xz

        if [ $( tar -tf data.tar | grep System.map ) ]; then
            tar --wildcards -x ./usr/lib/debug/boot/System.map-${KERN_VAR} -f data.tar
            tar --wildcards -x ./usr/lib/debug/boot/vmlinux-${KERN_VAR} -f data.tar
            ${SCRIPTDIR}/dwarf2json linux --system-map ${TEMP_DIR}/temp_kernel/usr/lib/debug/boot/System.map-${KERN_VAR} --elf ${TEMP_DIR}/temp_kernel/usr/lib/debug/boot/vmlinux-${KERN_VAR} | tee > ${TEMP_DIR}/${KERN_VAR}_${ARCH}.json
        else
            tar --wildcards -x ./usr/lib/debug/boot/vmlinux-${KERN_VAR} -f data.tar
            ${SCRIPTDIR}/dwarf2json linux --elf ${TEMP_DIR}/temp_kernel/usr/lib/debug/boot/vmlinux-${KERN_VAR} | tee > ${TEMP_DIR}/${KERN_VAR}_${ARCH}.json
        fi
        
        # Create banner.txt file
        grep -A15 linux_banner ${TEMP_DIR}/${KERN_VAR}_${ARCH}.json | grep constant_data | awk -F '"' '{print $4}' | base64 -d > ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${FULL_NAME}_banner.txt
        xz ${TEMP_DIR}/${KERN_VAR}_${ARCH}.json 
        mv ${TEMP_DIR}/${KERN_VAR}_${ARCH}.json.xz ${SYMBOL_DIR}/${DISTRO}/${KERN_VAR}/${KERN_VAR}_${ARCH}.json.xz
        rm ${TEMP_DIR}/${FULL_NAME}
    else
        echo "Unable to create symbol-file as data.tar.xz is missing after unpacking: ${FULL_NAME}"
        exit 1
    fi
}

_single_kernel() {
    # Create symbol-file based on provided kernel version
    KERN_VAR=$1
    for BRANCH in linux linux-aws linux-azure linux-gcp; do
        wget -U "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)" ${DOWNLOAD_SITE}/${BRANCH} -O ${TEMP_DIR}/index.html

        if [ $( grep '<a href="linux-image-'${KERN_VAR}'-dbgsym_'".*"'.ddeb">linux-image-' ${TEMP_DIR}/index.html | awk -F '<a href="' '{print $2}' | cut -f1 -d '"' ) ]; then
            MATCH=$( grep '<a href="linux-image-'${KERN_VAR}'-dbgsym_'".*"'.ddeb">linux-image-' ${TEMP_DIR}/index.html )
            echo "Found: ${KERN_VAR} link from download site."
            FULL_NAME=$( echo ${MATCH} | awk -F '<a href="' '{print $2}' | cut -f1 -d '"' )
            ARCH=$( echo ${FULL_NAME} | awk -F '_' '{print $NF}' | awk -F '.ddeb' '{print $1}' )
            _handle_deb ${KERN_VAR} ${FULL_NAME} ${ARCH} ${BRANCH}
            echo "Finished creating symbol-file for ${KERN_VAR}."
            exit 0
        else
            continue
        fi
    done
    echo "Didn't find: ${KERN_VAR} link at download site. Exiting."
    exit 1
}

_all_kernels() {
    # Create symbol-files for all kernels
    for BRANCH in linux linux-aws linux-azure linux-gcp; do
        wget -U "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)" ${DOWNLOAD_SITE}/${BRANCH} -O ${TEMP_DIR}/index.html
        for FULL_NAME in $( grep 'linux-image' ${TEMP_DIR}/index.html | grep '\-dbgsym_' | awk -F '<a href="' '{print $2}' | awk -F '">linux-image' '{print $1}' ); do
            ARCH=$( echo ${FULL_NAME} | awk -F '_' '{print $NF}' | awk -F '.ddeb' '{print $1}' )
            if [ $( echo ${FULL_NAME} | grep 'unsigned' ) ]; then
                KERN_VAR=$( echo ${FULL_NAME} | awk -F 'linux-image-unsigned-' '{print $2}' | awk -F '-dbgsym_' '{print $1}' )
            else
                KERN_VAR=$( echo ${FULL_NAME} | awk -F 'linux-image-' '{print $2}' | awk -F '-dbgsym_' '{print $1}' )
            fi
        _handle_deb ${KERN_VAR} ${FULL_NAME} ${ARCH} ${BRANCH}
        done
    done
}
