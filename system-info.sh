
#!/usr/bin/env bash
set -uo pipefail

# 1. System / mainboard make and model
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

# 2. CPU make / model / frequency range
cpu=$(awk -F ': ' '/^model name[[:space:]]*:/ {
    print $2; exit
}' /proc/cpuinfo)

cpu=${cpu:-$(lscpu 2>/dev/null |
    awk -F ': *' '/^Model name:/ {print $2; exit}')}

min_mhz=""
max_mhz=""

# Prefer the CPU's reported hardware frequency limits.
for f in /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq; do
    [[ -r "$f" ]] && min_mhz=$(($(cat "$f") / 1000))
done
for f in /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq; do
    [[ -r "$f" ]] && max_mhz=$(($(cat "$f") / 1000))
done

# Fallback to lscpu's reported minimum and maximum frequencies.
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
        'BEGIN {
            printf "%.1f - %.1f GHz", a/1000, b/1000
        }')
elif [[ -n "$max_mhz" ]]; then
    cpu_speed=$(awk -v b="$max_mhz" \
        'BEGIN {printf "%.1f GHz", b/1000}')
else
    # Some systems expose no frequency limits.
    cpu_speed=$(hwinfo --cpu 2>/dev/null |
        awk '/Clock:/ {print $2 " " $3; exit}')
fi

cpu=${cpu:-Unknown CPU}
[[ -n "$cpu_speed" ]] && cpu="$cpu @ $cpu_speed"

# 3. Installed RAM, rounded to the nearest whole GB.
# hwinfo often reports physical memory even when some is reserved.
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
    } END {if (total > 0) printf "%.0f", total}') 

if [[ -z "$ram_bytes" ]]; then
    ram_bytes=$(awk '/^MemTotal:/ {printf "%.0f", $2*1024}' \
        /proc/meminfo)
fi

ram_gb=$(awk -v b="$ram_bytes" \
    'BEGIN {printf "%.0f", b/1000000000}')
ram="${ram_gb}GB"

# 4. Primary storage backing the root filesystem
root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
disk=""

if [[ -n "$root_source" ]]; then
    # Resolve the root device to its underlying physical disk.
    disk=$(lsblk -s -nrpo NAME,TYPE "$root_source" 2>/dev/null |
        awk '$2 == "disk" {name=$1} END {print name}')
fi

# Fallback: first physical disk detected.
if [[ -z "$disk" ]]; then
    disk=$(lsblk -dnpo NAME,TYPE 2>/dev/null |
        awk '$2 == "disk" {print $1; exit}')
fi

if [[ -n "$disk" ]]; then
    size=$(lsblk -dnbo SIZE "$disk" 2>/dev/null | head -n 1)
    name=$(basename "$disk")

    size_gb=$(awk -v b="${size:-0}" \
        'BEGIN {printf "%.0f", b/1000000000}')

    if [[ "$name" == nvme* ]]; then
        type="NVMe SSD"
    elif [[ "$name" == sd* || "$name" == vd* ||
            "$name" == xvd* ]]; then
        rotational=$(lsblk -dnro ROTA "$disk" 2>/dev/null |
            head -n 1)
        if [[ "$rotational" == "0" ]]; then
            type="SSD"
        else
            type="HDD"
        fi
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
else
    storage="Unknown storage"
fi

# 5. Distribution name and version
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    os="${PRETTY_NAME:-${NAME:-Linux} ${VERSION_ID:-}}"
else
    os="Unknown OS"
fi

# Output
printf '%s\n%s\n%s\n%s\n%s\n' \
    "$system" "$cpu" "$ram" "$storage" "$os"

