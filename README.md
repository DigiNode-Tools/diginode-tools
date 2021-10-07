# DigiNode
## Tools for installing and monitoring a DigiByte and DigiAssets Node

These tools have been designed to make it as easy as possible to setup and monitor your own DigiNode on your Linux hardware of choice. The recommended device for this is a Raspberry Pi 4 8Gb.

WARNING: This script is still under development is should only be used for testing purposes until further notice.


## DigiNode Installer

Install script to set up your DigiNode - installs and configure DigiByte Core and the DigiAsset Metadata Server. It will also upgrade an existing install with any updates.

### Main Features

- Intuitively walks you though the process of installing a DigiByte Node and DigiAsset Node
- Almost no linux experience required. It does all the work for you. It's as plug-and-play as possible.
- Automatically checks for 64-bit linux OS at startup - it won't run on hardware it can't support.
- Detects compatible Raspberry Pi hardware (if present).
- Creates a swap file on low memory devices, and checks any existing swap file is big enough.
- Installs or upgrades DigiByte Core and DigiAssets Node with the latest releases from GitHub
- Creates or updates an digibyte.conf with required settings.
- Creates digibyted.service file to keep the DigiByte node running 24/7
- Creates or updates an DigiAsset config file with RPC settings. 
- Creates 'digibyte' user and sets system hostname to 'diginode'
- Enables zeroconf networking so you can access your node at http://diginode.local - no need to remember the IP address


## DigiNode Status Monitor

Let's you monitor your DigiNode from the terminal.

### Main Features

- Monitor your DigiNode on your local machine via the terminal, or remotely over SSH.
- Displays live DigiByte and DigiAsset data including:
    + Connection Count
    + Block Height (with Sync Progress)
    + IP addresses (local and external)
    + Web UI address
    + Node uptime
    + Disk, RAM and swap usage
- Periodically checks for software updates (not more than once every 24 hours) and helps you install them


### Bonus Features

- Verbose Mode: This provides much more detailed feedback on what the scripts are doing - useful for troubleshooting and debugging. Set variable at top of either script.
