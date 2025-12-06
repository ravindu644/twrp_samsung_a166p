#!/bin/bash
# Script to apply TWRP Samsung JDM Haptics patches before building recovery
# This should be called from BoardConfig.mk or AndroidProducts.mk

# Get the device tree directory (where this script lives)
DEVICE_TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE_1="$DEVICE_TREE/Patches/01.TWRP-Samsung-JDM-Vibration.patch"
PATCH_FILE_2="$DEVICE_TREE/Patches/02.TWRP-Add-Max-Vibration-Intensity.patch"

# Source root is 3 levels up from device tree
# device/samsung/a16xm -> ../../.. -> source root
SOURCE_ROOT="$(cd "$DEVICE_TREE/../../.." && pwd)"

# Lock file to prevent multiple simultaneous executions
LOCK_FILE="$SOURCE_ROOT/.jdm_patch_lock"
LOG_FILE="$DEVICE_TREE/jdm-patch.log"

# Check if lock exists (patch already applied in this build session)
if [[ -d "$LOCK_FILE" ]]; then
    exit 0
fi

# Create lock file
mkdir "$LOCK_FILE" 2>/dev/null || exit 0

set -e

# Redirect all output to log file
exec > "$LOG_FILE" 2>&1

echo "=== JDM Vibration Patches Application Log ==="
echo "Timestamp: $(date)"
echo "Device tree: $DEVICE_TREE"
echo "Source root: $SOURCE_ROOT"
echo "Patch file 1: $PATCH_FILE_1"
echo "Patch file 2: $PATCH_FILE_2"
echo ""

# Validate paths
if [[ ! -d "$SOURCE_ROOT" ]]; then
    echo "ERROR: Source root not found at $SOURCE_ROOT"
    exit 1
fi

if [[ ! -f "$PATCH_FILE_1" ]]; then
    echo "ERROR: Patch file 1 not found at $PATCH_FILE_1"
    exit 1
fi

if [[ ! -f "$PATCH_FILE_2" ]]; then
    echo "ERROR: Patch file 2 not found at $PATCH_FILE_2"
    exit 1
fi

# Change to source root
cd "$SOURCE_ROOT"

# Check if patches are already applied by looking for markers
MARKER_FILE_1="bootable/recovery/minuitwrp/events.cpp"
MARKER_FILE_2="bootable/recovery/gui/slidervalue.cpp"
PATCH_1_APPLIED=false
PATCH_2_APPLIED=false

if [[ -f "$MARKER_FILE_1" ]] && grep -q "#ifdef USE_SAMSUNG_JDM_HAPTICS" "$MARKER_FILE_1"; then
    PATCH_1_APPLIED=true
    echo "Patch 1 already applied (marker detected)"
fi

if [[ -f "$MARKER_FILE_2" ]] && grep -q "TW_MAX_VIBRATION_INTENSITY" "$MARKER_FILE_2"; then
    PATCH_2_APPLIED=true
    echo "Patch 2 already applied (marker detected)"
fi

if [[ "$PATCH_1_APPLIED" == true && "$PATCH_2_APPLIED" == true ]]; then
    echo "All patches already applied, skipping..."
    echo "Status: SUCCESS (already applied)"
    exit 0
fi

# Apply patch 1
if [[ "$PATCH_1_APPLIED" == false ]]; then
    echo "Applying patch 1: $(basename "$PATCH_FILE_1")..."
    if patch -p1 < "$PATCH_FILE_1"; then
        echo "Patch 1 applied successfully!"
    else
        # Check if marker exists now (might have failed but was already applied)
        if [[ -f "$MARKER_FILE_1" ]] && grep -q "#ifdef USE_SAMSUNG_JDM_HAPTICS" "$MARKER_FILE_1"; then
            echo "Patch 1 already applied (marker detected after failed attempt)"
        else
            echo "ERROR: Failed to apply patch 1"
            echo "Status: FAILED"
            exit 1
        fi
    fi
else
    echo "Skipping patch 1 (already applied)"
fi

# Apply patch 2
if [[ "$PATCH_2_APPLIED" == false ]]; then
    echo "Applying patch 2: $(basename "$PATCH_FILE_2")..."
    if patch -p1 < "$PATCH_FILE_2"; then
        echo "Patch 2 applied successfully!"
    else
        # Check if marker exists now (might have failed but was already applied)
        if [[ -f "$MARKER_FILE_2" ]] && grep -q "TW_MAX_VIBRATION_INTENSITY" "$MARKER_FILE_2"; then
            echo "Patch 2 already applied (marker detected after failed attempt)"
        else
            echo "ERROR: Failed to apply patch 2"
            echo "Status: FAILED"
            exit 1
        fi
    fi
else
    echo "Skipping patch 2 (already applied)"
fi

echo "Status: SUCCESS"
exit 0
