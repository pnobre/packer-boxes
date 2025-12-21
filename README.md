# Windows Vagrant Boxes

Build automated Vagrant boxes for Windows 10, Windows 11, and Windows Server 2025 using Packer.

## Prerequisites

### Install Required Tools

The following tools are required to build and manage the Windows virtual machine boxes:

- **VirtualBox** - Open-source virtualization software for running virtual machines
- **Vagrant** - Tool for building and managing virtual machine environments in a single workflow
- **VMware** - Enterprise-grade virtualization platform for running virtual machines with enhanced performance
- **Packer** - Automated tool for creating identical machine images for multiple platforms from a single source configuration
- **oscdimg** - Microsoft command-line tool for creating bootable ISO images from a directory structure

#### Option 1: Using WinGet (Recommended)
```powershell
winget install HashiCorp.Packer
winget install HashiCorp.Vagrant
winget install Oracle.VirtualBox
winget install Microsoft.OSCDIMG
# OR for VMware instead of VirtualBox:
# winget install VMware.WorkstationPro
```

#### Option 2: Using Chocolatey
```powershell
choco install packer
choco install vagrant
choco install virtualbox
choco install windows-adk-oscdimg
# OR for VMware instead of VirtualBox:
# choco install vmware-workstation-pro
```

#### Option 3: Manual Installation
- **Packer**: https://www.packer.io/downloads
- **Vagrant**: https://www.vagrantup.com/downloads
- **VirtualBox**: https://www.virtualbox.org/wiki/Downloads
- **VMware Workstation**: https://www.vmware.com/products/workstation/workstation-pro.html
- **oscdimg**: Install via WinGet (`Microsoft.OSCDIMG`) or as part of Windows ADK
#### Option 1: Using WinGet (Recommended)
```powershell
winget install HashiCorp.Packer
winget install HashiCorp.Vagrant
winget install Oracle.VirtualBox
# OR for VMware instead of VirtualBox:
# winget install VMware.WorkstationPro
```

#### Option 2: Using Chocolatey
```powershell
choco install packer
choco install vagrant
choco install virtualbox
# OR for VMware instead of VirtualBox:
# choco install vmware-workstation-pro
```

#### Option 3: Manual Installation
- **Packer**: https://www.packer.io/downloads
- **Vagrant**: https://www.vagrantup.com/downloads
- **VirtualBox**: https://www.virtualbox.org/wiki/Downloads
- **VMware Workstation**: https://www.vmware.com/products/workstation/workstation-pro.html
- **oscdimg**: https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install (select "Deployment Tools" component which includes oscdimg)

### Install Build Tools

Restore the .NET tools (FAKE build system):
```powershell
dotnet tool restore
```

## Build Targets

Run builds using the FAKE build system:

```powershell
dotnet fake build -t <target-name>
```

### Available Targets

#### ISO Download Targets
Download Windows ISO files with checksum verification:

- **`download-iso-win10`** - Downloads Windows 10 ISO
- **`download-iso-win11`** - Downloads Windows 11 ISO
- **`download-iso-server2025`** - Downloads Windows Server 2025 ISO
- **`download-all-isos`** - Downloads all ISO files

ISOs are automatically downloaded as dependencies before building, but you can download them manually:

```powershell
dotnet fake build -t download-all-isos
```

#### Build Targets
Create VM images (automatically downloads ISOs if needed):

- **`build-win10`** - Build Windows 10 box
- **`build-win11`** - Build Windows 11 box
- **`build-server2025`** - Build Windows Server 2025 box

Build a single OS:
```powershell
dotnet fake build -t build-win11
```

#### Package Targets
Create Vagrant boxes from built images:

- **`package-win10`** - Package Windows 10 box
- **`package-win11`** - Package Windows 11 box
- **`package-server2025`** - Package Windows Server 2025 box

Package a single OS:
```powershell
dotnet fake build -t package-win11
```

#### Full Build Targets
Build and package in one step:

```powershell
dotnet fake build -t build-win11
dotnet fake build -t package-win11
```

Or build everything:
```powershell
dotnet fake build -t all
```

### Build Options

Customize builds with optional parameters:

```powershell
# Build only for a specific hypervisor
dotnet fake build -t build-win11 -- --provider=virtualbox
# OR
dotnet fake build -t build-win11 -- --provider=vmware

# Customize Windows settings
dotnet fake build -t build-win11 -- --theme=Dark --locale=en-US --timezone="Eastern Standard Time"

# Combine options
dotnet fake build -t build-win11 -- --provider=virtualbox --theme=Dark --locale=en-GB --timezone="GMT Standard Time"
```

#### Available Options
- **`--provider=<virtualbox|vmware>`** - Build for specific hypervisor (default: both in parallel)
- **`--theme=<Light|Dark>`** - Windows theme (default: Light)
- **`--locale=<locale>`** - Windows locale (default: en-IE)
- **`--timezone=<timezone>`** - Windows timezone (default: GMT Standard Time)

## Performance Considerations

⚠️ **Important**: Building for both hypervisors simultaneously (default) requires significant system resources:

- **Minimum RAM**: 16 GB (8 GB per concurrent VM)
- **Disk Space**: 120 GB+ per OS image in progress
- **CPU**: Virtualization support enabled in BIOS

If your system has limited resources, build for one provider at a time:

```powershell
dotnet fake build -t build-win11 -- --provider=virtualbox
dotnet fake build -t build-win11 -- --provider=vmware
```

## Project Structure

```
.
├── build.fsx                          # FAKE build script
├── common/                            # Shared Packer files
│   ├── autounattend.xml              # Templated Windows unattend file
│   ├── variables.pkr.hcl             # Common Packer variables
│   ├── sources.pkr.hcl               # VirtualBox & VMware source configs
│   └── build.pkr.hcl                 # Shared provisioners & post-processors
├── windows-10/                        # Windows 10 overrides
│   └── windows-10.pkrvars.hcl
├── windows-11/                        # Windows 11 overrides
│   └── windows-11.pkrvars.hcl
├── windows-server-2025/               # Server 2025 overrides
│   └── windows-server-2025.pkrvars.hcl
├── scripts/                           # Provisioning scripts
│   ├── provision.ps1
│   ├── debloat.ps1
│   ├── cleanup.ps1
│   └── utilities.ps1
├── iso/                               # Downloaded ISO files
└── build/                             # Output VM images and boxes
```

## Notes

- All builds use SSH communicator for consistency
- The `autounattend.xml` is templated and reused across all Windows versions
- ISOs are cached in the `iso/` directory to avoid re-downloading
- Vagrant boxes are created with the template from `vagrant/Vagrantfile.windows-template`
