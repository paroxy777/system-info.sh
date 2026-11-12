# system-info

Displays basic system information in a concise, easy-to-read format.

Useful for system identification, hardware inventory, troubleshooting, and sales preparation.

## Sample Output

```text
LENOVO 20HGS0HK00
Intel(R) Core(TM) i7-7600U CPU @ 2.80GHz (0.4 - 3.9 GHz)
25GB RAM / 500 GB NVMe SSD / DVD
NVIDIA GeForce GTX 1050
Ubuntu 24.04.3 LTS
```

## Requirements

### Linux

Requires the `hwinfo` package.

Install using:

```bash
sudo apt install hwinfo
```

### Windows

- Windows 10 / 11
- Uses CIM/WMI for hardware information.
- PowerShell execution policy adjustment may be required.

Run using:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\system-info.ps1
```

## To-Do

- [ ] Improve dedicated GPU (dGPU) detection.
  - Add Intel Arc support.
  - Improve AMD integrated graphics detection.
  - Improve NVIDIA Optimus and hybrid graphics detection.

- [ ] Improve NVMe detection.
  - Use storage bus type instead of model-name matching.

- [ ] Improve CPU speed range detection.
  - Use power management data instead.

## Supported Platforms

| Platform | Implementation |
|---|---|
| Linux | `system-info.sh` |
| Windows | `system-info.ps1` |
| Windows CMD | `system-info.cmd` (requires system-info.ps1) |
