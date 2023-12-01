#!/usr/bin/env bash

msg(){
    echo
    echo "==> $*"
    echo
}

err(){
    echo 1>&2
    echo "==> $*" 1>&2
    echo 1>&2
}

defconfig_original="exynos9820-$2_defconfig"
defconfig_gcov="exynos9820-$2-gcov_defconfig"
defconfig_pgo="exynos9820-$2-pgo_defconfig"

mode="$1"
echo "Mode: $mode"
if [ "$mode" = "gcov" ]; then
    cp arch/arm64/configs/$defconfig_original arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_DEBUG_KERNEL=y"     >> arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_DEBUG_FS=y"         >> arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_GCOV_KERNEL=y"      >> arch/arm64/configs/$defconfig_gcov
    echo "CONFIG_GCOV_PROFILE_ALL=y" >> arch/arm64/configs/$defconfig_gcov
    defconfig=$defconfig_gcov
elif [ "$mode" = "pgo" ]; then
    cp arch/arm64/configs/$defconfig_original arch/arm64/configs/$defconfig_pgo
    echo "CONFIG_PGO=y"              >> arch/arm64/configs/$defconfig_pgo
    defconfig=$defconfig_pgo
elif [ "$mode" = "none" ]; then
    defconfig=$defconfig_original
fi

export ARCH="arm64"
export CROSS_COMPILE="aarch64-elf-"

msg "Generating defconfig from \`make $defconfig\`..."

if ! make O=out ARCH="arm64" $defconfig; then
    err "Failed generating .config, make sure it is actually available in arch/${arch}/configs/ and is a valid defconfig file"
    exit 2
fi

msg "Begin building kernel..."

make O=out ARCH="arm64" -j"$(nproc --all)" prepare

if ! make O=out ARCH="arm64" -j"$(nproc --all)"; then
    err "Failed building kernel, probably the toolchain is not compatible with the kernel, or kernel source problem"
    exit 3
fi

msg "Packaging the kernel..."

rm -rf out/ak3
cp -r ak3 out/

cp out/arch/arm64/boot/Image out/ak3/Image
tools/mkdtimg cfg_create out/ak3/dtb exynos9820.cfg -d out/arch/arm64/boot/dts/exynos

cd out/ak3
zip -r9 $2-$(/bin/date -u '+%Y%m%d-%H%M').zip .

