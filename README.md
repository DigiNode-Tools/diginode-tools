# DigiNode Tools

## Install and monitor your own DigiByte & DigiAssets Node

These tools have been designed to make it as easy as possible to setup and monitor your own DigiNode on your Linux hardware of choice. The recommended setup for this is a Raspberry Pi 4 8Gb running Ubuntu Server 64-bit.

* WARNING: This script is still under development and should only be used for testing purposes at this time.


## DigiNode Installer

Install script to set up your DigiNode - installs and configures a DigiByte Node and DigiAsset Node. It will also upgrade an existing install with any updates.

- Intuitively walks you though the process of installing a DigiByte Node and DigiAsset Node.
- Almost no linux experience required. It does all the work for you. It's as plug-and-play as possible.
- Automatically checks hardware and OS at launch - it lets you know if your system is compatible.
- Detects compatible Raspberry Pi hardware (if present).
- Creates a swap file on low memory devices, and checks if any existing swap file is large enough.
- Installs or upgrades DigiByte and DigiAssets software with the latest releases from GitHub.
- Creates or updates a digibyte.conf settings file with optimal settings.
- Creates digibyted.service file to keep the DigiByte Node running 24/7.
- Creates or updates an DigiAsset config file with RPC settings. 
- Creates 'digibyte' user and sets system hostname to 'diginode'.
- Enables zeroconf networking so you can access your node at http://diginode.local - no need to remember the IP address.


## DigiNode Status Monitor

Let's you monitor your DigiNode from the terminal.

- Monitor your DigiNode on your local machine via the terminal. I also works remotely over SSH.
- Displays live DigiByte and DigiAsset data including:
    + Connection Count
    + Block Height (with Sync Progress)
    + IP addresses (local and external)
    + Web UI address
    + Node uptime
    + Disk, RAM and swap usage
- Periodically checks for software updates (not more than once every 24 hours) and helps you install them.


## Bonus Features

- Verbose Mode: This provides much more detailed feedback on what the scripts are doing - useful for troubleshooting and debugging. Set variable at top of either script.
- Unattended Mode: This is useful for installing the script completely unattended. The defaults should be set from the ~/.digibyte/diginode.settings file. To run in unattended mode, use the --unattended flag at launch.
- Reset Mode: This is useful for repairing a default installation. It will delete and recreate the diginode.settings and digibyte.conf files and reinstall the DigiByte and DigiAssets software. Use with caution - it can mess up a custom installation. To run in reset mode, use the --reset flag at launch.


## Instructions

- To install your DigiNode, run the following command in the terminal:

# curl -sSL diginode-installer.digibyte.help | bash


## Advanced Users Only

These features are for advanced users and should be used with caution:

- Unattended Mode

Run this only having customized the settings in the ~/.digibyte/diginode.settings file. It will be created the first time you run this installer. Use with caution.

```curl -sSL diginode-installer.digibyte.help | bash -s -- --unattended```

- Reset Mode

This will reset and reinstall your current installation. Do not run this with a custom install or it will break things.

```curl -sSL diginode-installer.digibyte.help | bash -s -- --reset```

- Developer Mode

This use use the develop branch of the installer from Github, and install the develop version of DigiNode Tools. For testing purposes only. Expect this to break things. At times it likely won't even run.

```curl -sSL diginode-installer.digibyte.help | bash -s -- --develop```

- Skip OS Check

This will skip the OS check at startup in case you are having problems with your system. Proceed with caution.

```curl -sSL diginode-installer.digibyte.help | bash -s -- --skiposcheck```

- Uninstall [NOT YET WORKING]

Running this will uninstall your DigiNode. Your wallet file will be kept.

```curl -sSL diginode-installer.digibyte.help | bash -s -- --uninstall```



