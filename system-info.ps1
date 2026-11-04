# ============================================================
# SYSTEM INFORMATION
# Windows 10 / Windows 11
# ============================================================

# 1. SYSTEM MAKE / MODEL

$System = Get-CimInstance Win32_ComputerSystem

$Make = $System.Manufacturer.Trim()
$Model = $System.Model.Trim()

$SystemName = "$Make $Model"


# ============================================================
# 2. CPU / CLOCK SPEED
# ============================================================

$CPU = Get-CimInstance Win32_Processor | Select-Object -First 1

$CPUName = $CPU.Name.Trim()

$MinSpeed = $null
$MaxSpeed = $null

try {
    $Freq = Get-CimInstance `
        -Namespace root\wmi `
        -ClassName MSAcpi_ThermalZoneTemperature `
        -ErrorAction Stop
}
catch {}

# Processor maximum frequency

$MaxSpeed = $CPU.MaxClockSpeed

# Try to obtain minimum frequency from processor power settings

try {
    $Power = Get-CimInstance `
        -Namespace root\cimv2 `
        -ClassName Win32_Processor

    $MinSpeed = $Power.MinClockSpeed
}
catch {}

if ($MinSpeed -gt 0 -and $MaxSpeed -gt 0) {
    $CPUOutput = "$CPUName ($([math]::Round($MinSpeed / 1000,1)) - $([math]::Round($MaxSpeed / 1000,1)) GHz)"
}
elseif ($MaxSpeed -gt 0) {
    $CPUOutput = "$CPUName ($([math]::Round($MaxSpeed / 1000,1)) GHz)"
}
else {
    $CPUOutput = $CPUName
}


# ============================================================
# 3. RAM
# ============================================================

$RAMBytes = (
    Get-CimInstance Win32_PhysicalMemory |
    Measure-Object -Property Capacity -Sum
).Sum

$RAMGB = [math]::Round($RAMBytes / 1GB)

$RAMOutput = "${RAMGB}GB RAM"


# ============================================================
# 4. STORAGE
# ============================================================

$Disks = Get-CimInstance Win32_DiskDrive |
    Where-Object {
        $_.MediaType -notmatch "Removable"
    }

$StorageOutput = @()

foreach ($Disk in $Disks) {

    $SizeGB = [math]::Round($Disk.Size / 1GB)

    $Type = "Unknown"

    if ($Disk.Model -match "NVMe" -or
        $Disk.InterfaceType -eq "NVMe") {

        $Type = "NVMe SSD"
    }
    elseif ($Disk.MediaType -match "SSD") {

        $Type = "SSD"
    }
    elseif ($Disk.MediaType -match "Fixed hard disk") {

        $Type = "HDD"
    }
    else {

        # Fallback using physical disk information

        try {
            $Physical = Get-PhysicalDisk |
                Where-Object {
                    $_.FriendlyName -eq $Disk.Model
                } |
                Select-Object -First 1

            if ($Physical.MediaType -eq "SSD") {
                $Type = "SSD"
            }
            elseif ($Physical.MediaType -eq "HDD") {
                $Type = "HDD"
            }
        }
        catch {}
    }

    $StorageOutput += "$SizeGB GB $Type"
}

if ($StorageOutput.Count -eq 0) {
    $StorageOutput = @("Unknown storage")
}


# ============================================================
# 5. DVD
# ============================================================

$DVD = Get-CimInstance Win32_CDROMDrive |
    Where-Object {
        $_.Name -match "DVD"
    }

if ($DVD) {
    $StorageOutput += "DVD"
}

$HardwareOutput = "$RAMOutput / $($StorageOutput -join ' / ')"


# ============================================================
# 6. DEDICATED GPU ONLY
# ============================================================

$GPU = Get-CimInstance Win32_VideoController |
    Where-Object {

        $_.Name -notmatch "Intel.*(UHD|HD Graphics|Iris)" -and
        $_.Name -notmatch "Microsoft Basic Display"

    } |
    Where-Object {

        $_.Name -match "NVIDIA|GeForce|Quadro|RTX|Radeon RX|AMD Radeon Pro"

    } |
    Select-Object -First 1

$GPUOutput = $null

if ($GPU) {
    $GPUOutput = $GPU.Name.Trim()
}


# ============================================================
# 7. OPERATING SYSTEM
# ============================================================

$OS = Get-CimInstance Win32_OperatingSystem

$OSOutput = $OS.Caption

# Remove Microsoft prefix if present

$OSOutput = $OSOutput -replace "^Microsoft ", ""

# Add release/version information where available

$DisplayVersion = (Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
    -ErrorAction SilentlyContinue).DisplayVersion

if ($DisplayVersion) {
    $OSOutput = "$OSOutput $DisplayVersion"
}


# ============================================================
# OUTPUT
# ============================================================

Write-Output $SystemName
Write-Output $CPUOutput
Write-Output $HardwareOutput

if ($GPUOutput) {
    Write-Output $GPUOutput
}

Write-Output $OSOutput
