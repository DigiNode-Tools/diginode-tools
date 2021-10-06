# DigiNode
DigiNode - Tools for installing and monitoring a DigiByte and DigiAssets Node

WARNING: This script is still under development is should only be used for testing purposes until further notice.

## DigiNode Installer

Install script to set up your DigiNode - installs and configure DigiByte Core and
the DigiAsset Metadata Server. It will also upgrade an existing install with any updates.

Features:

- Ensures the script is being run on a 64-bit linux OS
- Detects compatible Raspberry Pi hardware (if present)
- Creates swap file on low memory devices
- Creates 'digibyte' user
- Sets hostname to 'diginode'
- Installs avahi-daemon so the web Ui can be accessed at https://diginode.local

Install DigiByte Core
- Installs or upgrades DigiByte Core with the latest release from GitHub
- Creates or updates digibyte.conf with required settings
- Creates digibyted.service file so the DigiByte node runs 24/7

Install DigiAsset Metadata Server
- Installs or upgrades IPFS daemon
- Install or upgrades DigiAssets Metadata Server
- Create configuration file


## DigiNode Status Monitor

Let's you monitor your DigiNode from the terminal over SSH. It will also periodically check for any updates
and help you install them.

Features:

- Ensures the script is being run on a 64-bit linux OS
- Detects compatible Raspberry Pi hardware (if present)
- Warns if swap file is not present on low memory devices
- Warns if port 12024 does not appear to be open (low connction count)
- Displays live DigiByte Core data including:
    Connection Count
    Block Height (with Sync Progress)
    IP addresses (local and external)
    Uptime
- Displays disk, memory and swap usage
- Checks for software updates every 24 hours (when running)
- Verbose Mode: Set variable at top of script (useful for debugging)

