#!/bin/bash

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Message helpers
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

usage() {
    cat <<EOF
${YELLOW}Usage:${NC} $0 <device_codename> <target> or $0 clean

Valid targets:
  1 (recoveryimage)      → recovery.img
  2 (bootimage)          → boot.img
  3 (vendorbootimage)    → vendor_boot.img

Examples:
  $0 lavender recoveryimage
  $0 lavender 1
  $0 clean
EOF
    exit 1
}

clean_out() {
    info "Cleaning output directory..."
    rm -rf out/
    info "Done cleaning."
}

choose_target() {
    local options=(
        "recoveryimage    → recovery.img"
        "bootimage        → boot.img"
        "vendorbootimage  → vendor_boot.img"
        "Cancel"
    )
    local values=("recoveryimage" "bootimage" "vendorbootimage" "Cancel")

    echo -e "${YELLOW}Please choose a build target by number:${NC}"
    for i in "${!options[@]}"; do
        printf "  %d. %s\n" "$((i+1))" "${options[i]}"
    done

    while true; do
        read -rp "Enter choice [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#values[@]} )); then
            selected="${values[$((choice-1))]}"
            if [[ "$selected" == "Cancel" ]]; then
                echo "Cancelled."
                exit 0
            else
                echo -e "${GREEN}Selected target:${NC} $selected"
                TARGET="$selected"
                break
            fi
        else
            echo "Invalid choice. Please enter a number between 1 and ${#values[@]}."
        fi
    done
}

compress_image() {
    local image_name="$1"
    local input_path="out/target/product/${DEVICE}/${image_name}.img"
    local output_dir="out/target/product/${DEVICE}"
    local output_path="${output_dir}/${image_name}.img.lz4"

    if [[ -f "$input_path" ]]; then
        mkdir -p "$output_dir"
        info "Compressing ${image_name}.img to ${output_path}"
        rm -rf "out/target/product/${DEVICE}/${image_name}.img.lz4"
        lz4 -B6 --content-size "$input_path" "$output_path" > /dev/null 2>&1 || error "Compression failed for ${image_name}.img"
        info "Compression complete: ${output_path}"
    else
        warn "Missing file: ${input_path}, skipping compression"
    fi
}

pack_tar() {
    local image_name="$1"
    local lz4_file="out/target/product/${DEVICE}/${image_name}.img.lz4"
    local tar_name="twrp-3.7.1_12-0-${DEVICE}.img.tar"

    if [[ -f "$lz4_file" ]]; then
        cp "$lz4_file" .
        info "Packing ${lz4_file} into ${tar_name}"
        tar cvf "$tar_name" "$(basename "$lz4_file")" > /dev/null 2>&1 || error "Failed to create tar file"
        rm -f "$(basename "$lz4_file")"
        info "Tar created: $tar_name"
    else
        warn "Missing .lz4 file for ${image_name}, skipping tar creation"
    fi
}

# --- Main logic ---

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
fi

if [[ "$1" == "clean" ]]; then
    clean_out
    exit 0
fi

if [[ $# -eq 0 ]]; then
    echo -e "${RED}Error: Missing arguments.${NC}"
    echo "Please run: $0 <device_codename> [<target>]"
    exit 1
fi

if [[ $# -gt 2 ]]; then
    echo -e "${RED}Error: Too many arguments.${NC}"
    echo "Please run: $0 <device_codename> [<target>]"
    exit 1
fi

DEVICE="$1"

if [[ $# -eq 1 ]]; then
    choose_target
else
    case "$2" in
        1) TARGET="recoveryimage" ;;
        2) TARGET="bootimage" ;;
        3) TARGET="vendorbootimage" ;;
        *) TARGET="$2" ;;  # fallback to string
    esac
fi

VALID_TARGETS=("recoveryimage" "bootimage" "vendorbootimage")
is_valid_target=false
for t in "${VALID_TARGETS[@]}"; do
    if [[ "$TARGET" == "$t" ]]; then
        is_valid_target=true
        break
    fi
done

if [[ "$is_valid_target" != true ]]; then
    error "Invalid target: $TARGET"
fi

info "Setting up build environment..."
[[ -f build/envsetup.sh ]] || error "Missing build/envsetup.sh"
source build/envsetup.sh || error "Failed to source build environment."

info "Lunching target: twrp_${DEVICE}-eng"
lunch "twrp_${DEVICE}-eng" || error "Lunch failed for device: $DEVICE"

info "Building: $TARGET"
make -j"$(nproc)" "$TARGET" || error "Build failed for target: $TARGET"

# Start compression and packaging according to target
case "$TARGET" in
    recoveryimage)
        compress_image "recovery"
        pack_tar "recovery"
        ;;
    bootimage)
        compress_image "boot"
        pack_tar "boot"
        ;;
    vendorbootimage)
        compress_image "vendor_boot"
        pack_tar "vendor_boot"
        ;;
esac
