#!/usr/bin/env bash

set -uo pipefail

# ============================================================
# 1. SYSTEM MAKE / MODEL
# ============================================================

manufacturer=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
board=$(cat /sys/class/dmi/id/board_name 2>/dev/null || true)

manufacturer=${manufacturer//$'\n'/}
product=${product//$'\n'/}
board=${board//$'\n'/}

if [[ -n "$product" && "$product" != "Default string" ]]; then
    system="$manufacturer $product"
elif [[ -n "$board" ]]; then
    system="$manufacturer $board"
else
    system=$(hwinfo --system --short 2>/dev/null |
        head -n 1 | xargs || true)
fi

system=${system:-Unknown system}


# ============================================================
# 2. CPU MAKE / MODEL / AVAILABLE CLOCK SPEEDS
# ============================================================

cpu=$(awk -F ': ' '/^model name[[:space:]]*:/ {
    print $2
    exit
}' /proc/cpuinfo)

cpu=${cpu:-$(lscpu 2>/dev/null |
    awk -F ': *' '/^Model name:/ {print $2; exit}')}

min_mhz=""
max_mhz=""
cpu_speed=""

# Hardware frequency limits

if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq ]]; then
    min_mhz=$(($(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq) / 1000))
fi

if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]]; then
    max_mhz=$(($(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq) / 1000))
fi

# Fallback to lscpu

if [[ -z "$max_mhz" ]]; then
    read -r min_mhz max_mhz < <(
        lscpu 2>/dev/null | awk -F ': *' '
        /^CPU min MHz:/ {min=$2}
        /^CPU max MHz:/ {max=$2}
        END {
            if (min != "" && max != "")
                printf "%d %d\n", min, max
        }'
    ) || true
fi

if [[ -n "$min_mhz" && -n "$max_mhz" ]]; then
    cpu_speed=$(awk -v a="$min_mhz" -v b="$max_mhz" \
        'BEGIN {printf "%.1f - %.1f GHz", a/1000, b/1000}')
elif [[ -n "$max_mhz" ]]; then
    cpu_speed=$(awk -v b="$max_mhz" \
        'BEGIN {printf "%.1f GHz", b/1000}')
fi

cpu=${cpu:-Unknown CPU}

[[ -n "$cpu_speed" ]] && cpu="$cpu ($cpu_speed)"


# ============================================================
# 3. RAM / STORAGE / DVD
# ============================================================

# RAM

ram_bytes=$(hwinfo --memory 2>/dev/null |
    awk '/Memory Size:/ {
        for (i=1; i<=NF; i++) {
            if ($i == "Size:") {
                n=$(i+1)
                u=$(i+2)

                if (u ~ /^GB/) total += n*1000000000
                else if (u ~ /^MB/) total += n*1000000
                else if (u ~ /^TB/) total += n*1000000000000
                else if (u ~ /^KB/) total += n*1000
            }
        }
    }
    END {
        if (total > 0) printf "%.0f", total
    }')

if [[ -z "$ram_bytes" ]]; then
    ram_bytes=$(awk '/^MemTotal:/ {
        printf "%.0f", $2*1024
    }' /proc/meminfo)
fi

ram_gb=$(awk -v b="$ram_bytes" \
    'BEGIN {printf "%.0f", b/1000000000}')

ram="${ram_gb}GB RAM"


# STORAGE

root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)

disk=""

if [[ -n "$root_source" ]]; then
    disk=$(lsblk -s -nrpo NAME,TYPE "$root_source" 2>/dev/null |
        awk '$2 == "disk" {name=$1} END {print name}')
fi

# Fallback to first physical disk

if [[ -z "$disk" ]]; then
    disk=$(lsblk -dnpo NAME,TYPE 2>/dev/null |
        awk '$2 == "disk" {print $1; exit}')
fi

storage="Unknown storage"

if [[ -n "$disk" ]]; then

    size=$(lsblk -dnbo SIZE "$disk" 2>/dev/null | head -n 1)
    name=$(basename "$disk")

    size_gb=$(awk -v b="${size:-0}" \
        'BEGIN {printf "%.0f", b/1000000000}')

    if [[ "$name" == nvme* ]]; then
        type="NVMe SSD"

    elif [[ "$name" == mmcblk* ]]; then
        type="eMMC"

    else
        rotational=$(lsblk -dnro ROTA "$disk" 2>/dev/null |
            head -n 1)

        if [[ "$rotational" == "0" ]]; then
            type="SSD"
        else
            type="HDD"
        fi
    fi

    storage="${size_gb} GB ${type}"
fi


# DVD / OPTICAL DRIVE

dvd=""

if lsblk -dnro TYPE 2>/dev/null | grep -qx rom; then
    dvd="DVD"
fi

hardware="$ram / $storage"

[[ -n "$dvd" ]] && hardware="$hardware / $dvd"


# ============================================================
# 4. DEDICATED GPU
# ============================================================

gpu=""

if command -v lspci >/dev/null 2>&1; then

    gpu=$(lspci 2>/dev/null |
        awk '
        /VGA compatible controller|3D controller|Display controller/ {
            if ($0 ~ /NVIDIA Corporation|Advanced Micro Devices|AMD\/ATI/) {
                sub(/^[^:]+: /, "")
                sub(/ \(rev .*$/, "")
                print
                exit
            }
        }')
fi

# NVIDIA fallback

if [[ -z "$gpu" ]] && command -v nvidia-smi >/dev/null 2>&1; then
    gpu=$(nvidia-smi --query-gpu=name \
        --format=csv,noheader 2>/dev/null | head -n 1)
fi


# ============================================================
# 5. OPERATING SYSTEM / DISTRIBUTION / VERSION
# ============================================================

if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    os="${PRETTY_NAME:-${NAME:-Linux} ${VERSION_ID:-}}"
else
    os="Unknown OS"
fi


# ============================================================
# OUTPUT
# ============================================================

printf '%s\n' "$system"
printf '%s\n' "$cpu"
printf '%s\n' "$hardware"

[[ -n "$gpu" ]] && printf '%s\n' "$gpu"

printf '%s\n' "$os"
