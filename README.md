# Windows Vagrant Boxes

Build automated Vagrant boxes for Windows 10, Windows 11, and Windows Server 2025 using Packer.

## ⚠️ Security Notice - Local Use Only

**These Vagrant boxes are designed for local development and testing purposes only.**

For performance and usability in development environments, these boxes include several optimizations that make them **unsuitable for production use**:

- **Windows Defender is disabled** - Real-time protection and antivirus scanning are turned off to improve performance during development
- **Security features are relaxed** - Various security settings are modified for easier local testing
- **No hardening applied** - These images are not hardened against security threats

**These boxes should only be used in trusted, isolated local environments. Do not deploy them to production, share them publicly, or use them in any security-sensitive context.**

For production use cases, you should:
- Re-enable Windows Defender and all security features
- Apply appropriate security hardening
- Follow your organization's security policies and compliance requirements
- Consider using official, hardened Windows images from Microsoft or other trusted sources

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

- **`download-iso-windows-10`** - Downloads Windows 10 ISO
- **`download-iso-windows-11`** - Downloads Windows 11 ISO
- **`download-iso-windows-server-2025`** - Downloads Windows Server 2025 ISO
- **`download-all-isos`** - Downloads all ISO files

ISOs are automatically downloaded as dependencies before building, but you can download them manually:

```powershell
dotnet fake build -t download-all-isos
```

#### Build Targets
Create VM images and Vagrant boxes (automatically downloads ISOs if needed):

- **`build-windows-10`** - Build Windows 10 box
- **`build-windows-11`** - Build Windows 11 box
- **`build-windows-server-2025`** - Build Windows Server 2025 box
- **`all`** - Build all boxes

Build a single OS:
```powershell
dotnet fake build -t build-windows-11
```

Build everything:
```powershell
dotnet fake build -t all
```

#### Add Box Targets
Add built boxes to your local Vagrant installation:

- **`deploy-windows-10`** - Add Windows 10 box to Vagrant
- **`deploy-windows-11`** - Add Windows 11 box to Vagrant
- **`deploy-windows-server-2025`** - Add Windows Server 2025 box to Vagrant

Add a box to Vagrant:
```powershell
dotnet fake build -t deploy-windows-11
```

Note: The box will be added with the name matching the OS (e.g., `windows-11`). The `--force` flag is used, so it will overwrite any existing box with the same name.

#### Clean Targets
Remove build artifacts:

- **`clean`** - Remove build and boxes directories
- **`full-clean`** - Remove build artifacts and downloaded ISOs

```powershell
dotnet fake build -t clean
# OR to also delete downloaded ISOs:
dotnet fake build -t full-clean
```

### Build Options

Customize builds with optional parameters:

```powershell
# Build only for a specific hypervisor
dotnet fake build -t build-windows-11 -- --provider=virtualbox
# OR
dotnet fake build -t build-windows-11 -- --provider=vmware

# Customize Windows settings
dotnet fake build -t build-windows-11 -- --theme=Dark --locale=en-US --timezone="Eastern Standard Time"

# Combine options
dotnet fake build -t build-windows-11 -- --provider=virtualbox --theme=Dark --locale=en-GB --timezone="GMT Standard Time"
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
dotnet fake build -t build-windows-11 -- --provider=virtualbox
dotnet fake build -t build-windows-11 -- --provider=vmware
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
├── build/                             # Temporary VM build artifacts
└── boxes/                             # Final Vagrant box files
```

## Output

After building, you'll find:
- **VM artifacts** in `build/<os-name>/<provider>/`
- **Vagrant boxes** in `boxes/<os-name>/<provider>/<os-name>-<provider>.box`

## Notes

- All builds use SSH communicator for consistency
- The `autounattend.xml` is templated and reused across all Windows versions
- ISOs are cached in the `iso/` directory to avoid re-downloading
- Vagrant boxes are created with the template from `vagrant/Vagrantfile.windows-template`
- The build process automatically packages the VMs into Vagrant boxes
