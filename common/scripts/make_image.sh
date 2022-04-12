#!/usr/bin/env bash

# Copyright (c) 2021-2022, ARM Limited and Contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Neither the name of ARM nor the names of its contributors may be used
# to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

#------------------------------------------
# Generate the disk image for busybox boot
#------------------------------------------


#variables for image generation
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOP_DIR=`pwd`
PLATDIR=${TOP_DIR}/output
OUTDIR=${PLATDIR}
GRUB_FS_CONFIG_FILE=${TOP_DIR}/build-scripts/config/grub.cfg
GRUB_ARM_FS_CONFIG_FILE=${TOP_DIR}/build-scripts/config/grub-arm.cfg
EFI_CONFIG_FILE=${TOP_DIR}/build-scripts/config/startup.nsh
BSA_CONFIG_FILE=${TOP_DIR}/build-scripts/config/bsa.nsh
BBR_CONFIG_FILE=${TOP_DIR}/build-scripts/config/bbr.nsh
DEBUG_CONFIG_FILE=${TOP_DIR}/build-scripts/config/debug_dump.nsh
BLOCK_SIZE=512
SEC_PER_MB=$((1024*2))
GRUB_PATH=grub
UEFI_SHELL_PATH=edk2/Build/Shell/RELEASE_GCC5/AARCH64/
UEFI_ARM_SHELL_PATH=edk2/Build/Shell/RELEASE_GCC5/ARM/
BSA_EFI_PATH=edk2/Build/Shell/DEBUG_GCC49/AARCH64/
BSA_EFI_ARM_PATH=edk2/Build/Shell/DEBUG_GCC49/AARCH64/
SCT_PATH=edk2-test/uefi-sct/AARCH64_SCT
SCT_ARM_PATH=edk2-test/uefi-sct/ARM_SCT
UEFI_APPS_PATH=${TOP_DIR}/edk2/Build/MdeModule/DEBUG_GCC5/AARCH64
UEFI_APPS_ARM_PATH=${TOP_DIR}/edk2/Build/MdeModule/DEBUG_GCC5/AARCH64

create_cfgfiles ()
{
    local fatpart_name="$1"

    if [ -f bootarm.efi ]; then
        mcopy -i  $fatpart_name -o ${GRUB_ARM_FS_CONFIG_FILE} ::/grub.cfg
    else
        mcopy -i  $fatpart_name -o ${GRUB_FS_CONFIG_FILE} ::/grub.cfg
    fi
    mcopy -i  $fatpart_name -o ${EFI_CONFIG_FILE}     ::/EFI/BOOT/startup.nsh
    mcopy -i  $fatpart_name -o ${BSA_CONFIG_FILE}    ::/EFI/BOOT/bsa/bsa.nsh
    mcopy -i  $fatpart_name -o ${DEBUG_CONFIG_FILE}    ::/EFI/BOOT/debug/debug_dump.nsh
    #mcopy -i  $fatpart_name -o ${BBR_CONFIG_FILE}    ::/EFI/BOOT/bbr/bbr.nsh

}

create_fatpart ()
{
    local fatpart_name="$1"  #Name of the FAT partition disk image
    local fatpart_size="$2"  #FAT partition size (in 512-byte blocks)

    dd if=/dev/zero of=$fatpart_name bs=$BLOCK_SIZE count=$fatpart_size
    mkfs.vfat $fatpart_name -n $fatpart_name
    mmd -i $fatpart_name ::/EFI
    mmd -i $fatpart_name ::/EFI/BOOT
    mmd -i $fatpart_name ::/grub
    mmd -i $fatpart_name ::/EFI/BOOT/bsa
    if [ "$BUILD_PLAT" = "SR" ]; then
        mmd -i $fatpart_name ::/EFI/BOOT/bsa/sbsa
    fi
    mmd -i $fatpart_name ::/EFI/BOOT/bbr
    mmd -i $fatpart_name ::/EFI/BOOT/debug
    mmd -i $fatpart_name ::/EFI/BOOT/app

    if [ -f bootarm.efi ]; then
        mcopy -i $fatpart_name bootarm.efi ::/EFI/BOOT
    fi
    if [ -f bootaa64.efi ]; then
        mcopy -i $fatpart_name bootaa64.efi ::/EFI/BOOT
    fi
    if [ -f Shell.efi ]; then
        mcopy -i $fatpart_name Shell.efi ::/EFI/BOOT
    fi
    if [ -f $OUTDIR/Image ]; then
        mcopy -i $fatpart_name $OUTDIR/Image ::/
    fi
    if [ -f $OUTDIR/zImage ]; then
        mcopy -i $fatpart_name $OUTDIR/zImage ::/
    fi
    mcopy -i $fatpart_name $PLATDIR/ramdisk-busybox.img  ::/

    if [ "$BUILD_PLAT" = "SR" ]; then
        if [ -f Sbsa.efi ]; then
            mcopy -i $fatpart_name Sbsa.efi ::/EFI/BOOT/bsa/sbsa
        fi
    else
        if [ -f Bsa.efi ]; then
            mcopy -i $fatpart_name Bsa.efi ::/EFI/BOOT/bsa
        fi
    fi

    if [ -d SCT ]; then
        mcopy -s -i $fatpart_name SCT/* ::/EFI/BOOT/bbr
    fi
    if [ "$BUILD_PLAT" = "IR" ]; then
      echo " IR BSA flag file copied"
      if [ -f ${TOP_DIR}/build-scripts/ir_bsa.flag ]; then
        mcopy -i $fatpart_name ${TOP_DIR}/build-scripts/ir_bsa.flag ::/EFI/BOOT/bsa
      fi
    fi
    if [ -f ${UEFI_APPS_PATH}/CapsuleApp.efi ]; then
        mcopy -i $fatpart_name ${UEFI_APPS_PATH}/CapsuleApp.efi ::/EFI/BOOT/app
    fi
    if [ -f ${UEFI_APPS_ARM_PATH}/CapsuleApp.efi ]; then
        mcopy -i $fatpart_name ${UEFI_APPS_ARM_PATH}/CapsuleApp.efi ::/EFI/BOOT/app
    fi

    echo "FAT partition image created"
}

create_fatpart2 ()
{
    local fatpart_name="$1"  #Name of the FAT partition disk image
    local fatpart_size="$2"  #FAT partition size (in 512-byte blocks)

    dd if=/dev/zero of=$fatpart_name bs=$BLOCK_SIZE count=$fatpart_size
    mkfs.vfat $fatpart_name -n $fatpart_name
    mmd -i $fatpart_name ::/acs_results
    echo "FAT partition 2 image created"
}

create_diskimage ()
{
    local image_name="$1"
    local part_start="$2"
    local fatpart_size="$3"
    local fatpart2_size="$4"

    (echo n; echo 1; echo $part_start; echo +$((fatpart_size-1));\
    echo 0700; echo w; echo y) | gdisk $image_name
    (echo n; echo 2; echo $((part_start+fatpart_size)); echo +$((fatpart2_size-1));\
    echo 0700; echo w; echo y) | gdisk $image_name
}

prepare_disk_image ()
{
    echo
    echo
    echo "-------------------------------------"
    echo "Preparing disk image for busybox boot"
    echo "-------------------------------------"

    if [ "$BUILD_PLAT" = "ES" ]; then
       IMG_BB=es_acs_live_image.img
       echo -e "\e[1;32m Build ES Live Image at $PLATDIR/$IMG_BB \e[0m"
    elif [ "$BUILD_PLAT" = "IR" ]; then
       IMG_BB=ir_acs_live_image.img
       echo -e "\e[1;32m Build IR Live Image at $PLATDIR/$IMG_BB \e[0m"
    elif [ "$BUILD_PLAT" = "SR" ]; then
       IMG_BB=sr_acs_live_image.img
       echo -e "\e[1;32m Build SR Live Image at $PLATDIR/$IMG_BB \e[0m"
    else
       echo "Specify platform ES, IR or SR"
       exit_fun
    fi

    pushd $TOP_DIR/$GRUB_PATH/output

    local FAT_SIZE_MB=512
    local FAT2_SIZE_MB=50
    local PART_START=$((1*SEC_PER_MB))
    local FAT_SIZE=$((FAT_SIZE_MB*SEC_PER_MB))
    local FAT2_SIZE=$((FAT2_SIZE_MB*SEC_PER_MB))

    rm -f $PLATDIR/$IMG_BB
    if [ -f grubaa64.efi ]; then
        cp grubaa64.efi bootaa64.efi
    fi
    if [ -f grubarm.efi ]; then
        cp grubarm.efi bootarm.efi
    fi
    if [ -f $TOP_DIR/$UEFI_SHELL_PATH/Shell_EA4BB293-2D7F-4456-A681-1F22F42CD0BC.efi ]; then
        echo "ARM64 copy ARM64 shell"
        cp $TOP_DIR/$UEFI_SHELL_PATH/Shell_EA4BB293-2D7F-4456-A681-1F22F42CD0BC.efi Shell.efi
    fi
    if [ -f $TOP_DIR/$UEFI_ARM_SHELL_PATH/Shell_EA4BB293-2D7F-4456-A681-1F22F42CD0BC.efi ]; then
        echo "copy ARM shell"
        cp $TOP_DIR/$UEFI_ARM_SHELL_PATH/Shell_EA4BB293-2D7F-4456-A681-1F22F42CD0BC.efi Shell.efi
    fi

    if [ "$BUILD_PLAT" = "SR" ]; then
        cp $TOP_DIR/$BSA_EFI_PATH/Sbsa.efi Sbsa.efi
    else
        if [ -f $TOP_DIR/$BSA_EFI_PATH/Bsa.efi ]; then
            echo "ARM64 copy ARM64 bsa"
            cp $TOP_DIR/$BSA_EFI_PATH/Bsa.efi Bsa.efi
        fi
        if [ -f $TOP_DIR/$BSA_EFI_ARM_PATH/Bsa.efi ]; then
            echo "copy ARM bsa"
            cp $TOP_DIR/$BSA_EFI_ARM_PATH/Bsa.efi Bsa.efi
        fi
    fi

    if [ -d $TOP_DIR/$SCT_PATH/ ]; then
        echo "copy ARM64 sct"
        cp -Tr $TOP_DIR/$SCT_PATH/ SCT
    fi
    if [ -d $TOP_DIR/$SCT_ARM_PATH/ ]; then
        echo "copy ARM sct"
        cp -Tr $TOP_DIR/$SCT_ARM_PATH/ SCT
    fi
    grep -q -F 'mtools_skip_check=1' ~/.mtoolsrc || echo "mtools_skip_check=1" >> ~/.mtoolsrc

    #Package images for Busybox
    rm -f $IMG_BB
    dd if=/dev/zero of=part_table bs=$BLOCK_SIZE count=$PART_START

    #Space for partition table at the top
    cat part_table > $IMG_BB

    #Create fat partition
    create_fatpart "BOOT" $FAT_SIZE
    create_cfgfiles "BOOT"
    cat BOOT >> $IMG_BB

    #Result partition
    create_fatpart2 "RESULT" $FAT2_SIZE
    cat RESULT >> $IMG_BB
    
    #Space for backup partition table at the bottom (1M)
    cat part_table >> $IMG_BB

    # create disk image and copy into output folder
    create_diskimage $IMG_BB $PART_START $FAT_SIZE $FAT2_SIZE
    cp $IMG_BB $PLATDIR

    #remove intermediate files
    rm -f part_table
    rm -f BOOT
    rm -f RESULT

    echo "Compressing the image : $PLATDIR/$IMG_BB"
    xz -z $PLATDIR/$IMG_BB

    if [ -f $PLATDIR/$IMG_BB.xz ]; then
        echo "Completed preparation of disk image for busybox boot"
        echo "Image path : $PLATDIR/$IMG_BB.xz"
    fi
    echo "----------------------------------------------------"
}
exit_fun() {
   exit 1 # Exit script
}

BUILD_PLAT=$1

if [ -z "$BUILD_PLAT" ]
then
   echo "Specify platform ES, IR or SR"
   exit_fun
fi
#prepare the disk image
prepare_disk_image

