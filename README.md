![DigiNode Tools Logo](images/diginode_tools_logo.png)

# DigiNode Tools

### What's a DigiNode?
A DigiNode is a device that runs a [DigiByte](https://digibyte.org/) Full Node and [DigiAsset Node](https://ipfs.digiassetx.com/) helping to further decentralize the DigiByte ecosystem. 

### What are DigiNode Tools?
DigiNode Tools are a suite of linux bash scripts that make it easy to setup, monitor and manage your DigiNode via the linux command line:
- **DigiNode Setup** - Helps you to install, upgrade, backup and restore your DigiByte and/or DigAsset Node.
- **DigiNode Status Monitor** - Provides a live dashboard to quickly check the status of your DigiNode.

For more information, visit: https://diginode.tools

### What do I need to run a DigiNode?

DigiNode Tools should run on most Ubuntu or Debian based systems. A 64-bit OS is required. Both ARM64 and x86_64 hardware are supported. It has been designed with headless operation in mind. A device with at least 8GB RAM is recommended. A Raspberry Pi 4 8Gb is a good choice. See the Compatibility section below. 

A DigiNode is designed to operate "headless". This means you do not need a display, keyboard or mouse - everything is setup and managed remotely, using the terminal.

If you are interested in building your own DigiNode, the recommended setup is a **Raspberry Pi 4 8Gb** with an **SSD** running **Raspberry Pi OS Lite 64-bit**.  See [here](/docs/suggested_hardware.md) for the parts you need.

## Disclaimer

These tools are provided as is. Use at your own risk. Always keep a backup of your DigiByte wallet. 

## Get Started

To get started, follow the instuctions below for you specific system.

Note: DigiNode Setup gives you the option to install DigiNode Tools only (i.e. these scripts). If you already have a DigiByte Node installed, and want to use the status monitor with it, you may want to choose this option. The scripts will be installed to: ~/diginode-tools

### Setup a DigiNode on Raspberry Pi

Go [here](docs/rpi_setup.md) for detailed step-by-step instructions on how to setup a DigiNode on a Raspberry Pi.

### Setup a DigiNode on Debian

On your Debian system, launch DigiNode Setup by entering the following command in the terminal:

```curl -sSL setup.diginode.tools | bash```

### Setup a DigiNode on Ubuntu

Due to a bug in the latest Ubuntu release, is is not currently possible to run the install script directly from Github - when you do, the menus will become unresponsive. (If you find yourself in this situation you can press Ctrl-C to Exit.)

Until a fix is released, the workaround is to first download DigiNode Tools and then run it from your local machine. Enter the following command to download it:

```cd ~ && DGNT_VER_RELEASE=$(curl -sL https://api.github.com/repos/saltedlolly/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//') && git clone --depth 1 --quiet --branch v${DGNT_VER_RELEASE} https://github.com/saltedlolly/diginode-tools/ 2>/dev/null && touch ~/diginode-tools/ubuntu-workaround && chmod +x ~/diginode-tools/diginode-setup.sh```

This command need only be run once. The latest release of DigiNode Tools will be downloaded to ~/diginode-tools. Once downloaded, you can run DigiNode Setup by entering:

```~/diginode-tools/diginode-setup.sh```

(Note: If needed, flags from the 'Advanced Features' section can be appended to this command.)

## Support

If you need help, please join the [DigiNode Tools Telegram group](https://t.me/DigiNodeTools). You can also reach out to [@digibytehelp](https://twitter.com/digibytehelp) on Twitter.

## Donations

I created DigiNode Tools because I want to make it easy for everyone to run their own DigiByte and DigiAsset Node. So far, I have devoted thousands of unpaid hours working towards this goal. If you find these tools useful, please make a donation to support my work. 

Many thanks, Olly   >> Find me on Twitter [@saltedlolly](https://twitter.com/saltedlolly) <<

**dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup**

![DigiByte Donation QR Code](images/donation_qr_code.png)

## About DigiNode Setup

![DigiNode Setup](images/diginode_install_menu.png)
DigiNode Setup helps you to setup and manage your DigiNode:

- Intuitively walks you though the process of setting up a full DigiNode, a DigiByte Node ONLY or a DigiAsset Node ONLY. 
- Almost no linux command line experience required. It does all the work for you. It's as plug-and-play as possible.
- Automatically checks hardware and OS at launch - it detects compatible Raspberry Pi hardware (if present) and lets you know if your system is compatible, and that there is enough disk space and memory to a DigiNode.
- Checks if the existing swap file is large enough, and helps create one on low memory devices.
- Installs or upgrades DigiByte and DigiAssets Node software with the latest releases from GitHub.
- Creates or updates the digibyte.conf settings file with optimal settings.
- Creates system services (systemd or upstart) to ensure the DigiByte Node and DigiAsset Node stays running 24/7.
- Creates or updates your DigiAsset Node configuration file with your RPC credentials. (This ensures you can always access your wallet from the web UI to mint DigiAssets.)
- Optionally, creates a 'digibyte' user and sets system hostname to 'diginode'. It also enables zeroconf networking (Bonjour) so you can access your node at http://diginode.local - i.e. no need to remember the IP address.
- Installs DigiNode Tools (these setup scripts) and the DigiNode Status Monitor. (see below)

To get started, see the "Get Started" section above. Once installed, DigiNode Setup can be run from the command line by entering: ```diginode-setup```

## Additional Features

![DigiNode Main Menu](images/diginode_main_menu.png)
Once DigiNode Tools have been installed, you can access additional features via the DigiNode Setup menu by entering: ```diginode-setup```

- **Update**: Installs any software updates for your DigiNode, and checks that all services are running correctly. It also ensures that the RPC credentials are correct and that the DigiAsset Node is able to connect with the DigiByte Node. Most DigiNode issues can be solved by performing an Update.
- **Backup**: Helps you to backup your DigiByte wallet and/or your DigiAsset Node settings to an external USB stick.
- **Restore**: Helps you to restore your DigiNode from an existing backup.
- **Ports**: Enable/disable using UPnP to forward required ports.
- **Network**: Switch between running DigiByte Core on mainnet or testnet
- **MOTD**: Enable the custom DigiNode Message of the Day. This displays the DigiNode logo and usage instructions whenever you login via the terminal.
- **Extras**: Install additional software such as the cooling fan software for the Argon ONE case for the Rasperry Pi.
- **Reset**: Gives you the ability to selectively reset your DigiNode settings in the event of a problem.
- **Uninstall**: Unistalls DigiNode software from your system. It lets you choose which individual components you wish to remove. Your DigByte wallet will not be harmed.

## About DigiNode Status Monitor

![DigiNode Status Monitor](images/diginode_status_monitor.png)

DigiNode Status Monitor let's you monitor your DigiNode from the command line:

- Monitor your DigiNode on your local machine via the command line, locally or remotely over SSH.
- Quickly check that your DigiByte and DigiAsset Nodes are running correctly.
- Displays live DigiByte and DigiAsset data including:
    + Connection Count
    + Block Height (with Sync Progress)
    + IP addresses (local and external)
    + Web UI address 
    + Node uptime
    + Disk, RAM and swap usage
- Periodically checks for software updates to your DigiNode (not more than once every 24 hours) and helps you install them.

DigiNode Status Monitor can be run from the command line by entering: ```diginode```

## Compatibility

DigiNode Tools should work with most Ubuntu or Debian based systems. A 64-bit OS is required. Both ARM64 and x86_64 hardware are supported. It has been designed with headless operation in mind. A device with at least 8GB RAM is recommended. A Raspberry Pi 4 8Gb is a good choice.
- With 8Gb RAM or more, you can safely run a full DigiNode (DigiByte + DigiAssets). This is the recommended minimum.
- With 4Gb RAM, you can run a DigiByte Node, or a DigiAsset Node, but running both together is not recommended. (Note: By creating a large swap file, it is technically possible to run a full DigiNode with only 4Gb RAM, but performance will be very sluggish. This is fine for testing, but definitely not recommended for long term use. Due the read/write demands placed on the SSD, its lifespan will be significantly decreased.)
- With 2Gb RAM, there is not enough memory to run a DigiByte Node, but you can still run DigiAsset Node. (A DigiAsset Node requires ~2Gb RAM.) See the Advanced Features section below for how to do a 'DigiAsset Node ONLY' setup.
- Regardless of how much memory your device has, it is always sensible to have a swap file. DigiNode Setup can help configure this for you.
- As of December 2022, the DigiByte blockchain currently requires around 43Gb of disk space. If you are setting up a DigiNode, a minimum 90Gb of free disk space is recommended, to allow for future growth.
- When using a Raspberry Pi 4, booting from an SSD via USB is highly recommended. If you have an 8Gb Pi, it is possible to boot from a microSD card, though this is not recommended for long term use.
- If you are interested in building your own DigiNode using a Raspberry Pi 4, you can find a list of the parts you need [here](docs/suggested_hardware.md).

DigiNode has been tested and known to work with the following systems:

| **Hardware**          | **Operating System**                               | **Notes**                                                                                                   |
|-----------------------|----------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| Raspberry Pi 4 8Gb    | Raspberry Pi OS lite 64-bit (Debian Bullseye)      | This is the recommended configuration. Booting from an SSD, rather than microSD, is highly recommended.     |
| Raspberry Pi 4 8Gb    | Ubuntu Server 22.04 LTS 64-bit                     | Booting from an SSD, rather than microSD, is highly recommended.  Note: There is currently a known issue with the recent releases of Ubuntu that causes the menus to become unresponsive when piping though bash. If you experience this, you may want to try using Raspberry Pi OS instead, or run the script locally with the workaround above. |
| Raspberry Pi 4 4Gb    | Raspberry Pi OS lite 64-bit (Debian Bullseye)      | Requires large swap file to run a full DigiNode. Runs slowly. Fine for testing - not recommended for long-term use. Recommended to run either a DigiByte node, or a DigiAsset node, but not both. |
| x86_64 (Intel/AMD)    | Ubuntu Server 22.04 LTS 64-bit                     | Tested and working on an Intel Core i3-380M laptop with 8Gb RAM. Requires the Ubuntu workaround explained above. |

## License

DigiNode Tools is licensed under the PolyForm Perimeter 1.0.0 license. TL;DR — You're free to use, fork, modify, and redestribute DigiNode Tools for personal and nonprofit use under the same license. However, you may not re-release DigiNode Tools in an official capacity (i.e. on a custom website or custom URL) in a form which competes with the original DigiNode Tools. This is to ensure that there remains only one official release version of DigiNode Tools. If you're interested in using DigiNode Tools for commercial purposes, such as selling plug-and-play home servers with DigiNode Tools, etc — please contact olly@digibyte.help. For more information read the [Licence FAQ](docs/licence_faq.md). The full licence is [here](LICENCE.md).

## Advanced Features

These features are for advanced users and should be used with caution:

**Unattended Mode:** This is useful for installing the script completely unattended. To run in unattended mode, use the --unattended flag at launch. 
- ```curl -sSL setup.diginode.tools | bash -s -- --unattended``` or
- ```diginode-setup --unattended```

Note: The first time you run DigiNode Setup in Unattended mode, it will create the required diginode.settings file and then exit. If you wish to customize your installation further, you can edit this file before proceeding. It is located here: ~/.digibyte/diginode.settings
If you want to skip this step, and simply use the default settings, include the --skipcustommsg flag:
- ```curl -sSL setup.diginode.tools | bash -s -- --unattended --skipcustommsg``` or
- ```diginode-setup --unattended --skipcustommsg```

**DigiAsset Node ONLY Setup:** If you have a low spec device that isn't powerful enough to run DigiByte Node, you can use the ```--dganodeonly``` flag to setup only a DigiAsset Node. Using this flag bypasses the hardware checks required for the DigiByte Node. A DigiAsset Node requires very little disk space or memory and should work on very low power devices. If you later decide you want to install a DigiByte Node as well, you can use the ```--fulldiginode``` flag to upgrade your existing DigiAsset Node setup. This can also be accessed from the main menu.
- ```curl -sSL setup.diginode.tools | bash -s -- --dganodeonly``` or
- ```diginode-setup --dganodeoonly```

**Reset Mode**: This will reset and reinstall your current installation using the default settings. It will delete digibyte.conf, diginode.settings and main.json and recreate them with default settings. It will also reinstall DigiByte Core and the DigiAsset Node. IPFS will not be re-installed. Do not run this with a custom install or it may break things. For best results, run a standard upgrade first, to ensure all software is up to date, before running a reset. Software can only be re-installed if it is most recent version. You can perform a Reset via the DigiNode Setup main menu by entering ```diginode-setup```. You can also use the --reset flag at launch.
- ```curl -sSL setup.diginode.tools | bash -s -- --reset``` or
- ```diginode-setup --reset```

**Skip OS Check:** The --skiposcheck flag will skip the OS check at startup in case you are having problems with your system. Proceed with caution.
- ```curl -sSL setup.diginode.tools | bash -s -- --skiposcheck``` or
- ```diginode-setup --skiposcheck```

**Skip Package Cache Update:** The --skippkgcache flag will skip trying to update the package cache at launch in case you are do not have permission to do this. (Some VPS won't let you update.)
- ```curl -sSL setup.diginode.tools | bash -s -- --skippkgcache``` or
- ```diginode-setup --skippkgcache```

**Uninstall:** The --uninstall flag will uninstall your DigiNode. Your DigiByte wallet will be kept. This can also be accessed from the main menu.
- ```curl -sSL setup.diginode.tools | bash -s -- --uninstall``` or
- ```diginode-setup --uninstall```

**Verbose Mode:** This provides much more detailed feedback on what the scripts are doing - useful for troubleshooting and debugging. This can be set using the ```--verboseon``` flags.
- ```curl -sSL setup.diginode.tools | bash -s -- --verboseon```
- ```diginode-setup --uninstall```

**Manually Locate DigiByte Core:** If you wish to use the DigiNode Status Monitor with your existing DigiByte Node (i.e. One not setup with DigiNode Tools), and the startup checks are not able to locate it automatically, use the ```--locatedgb``` flag at launch to manually specify the folder location.
- ```diginode --locatedgb```

**Developer Mode:** To install the development branch of DigiNode Tools, use the ```--dgntdev``` flag at launch. The ```--dgadev``` flag can be used to install the development branch of the DigiAsset Node. WARNING: These should only be used for testing, and occasionally may not run.
- ```curl -sSL setup.diginode.tools | bash -s -- --dgntdev --dgadev``` or
- ```diginode-setup --dgntdev --dgadev```

## Release Notes

Go [here](/docs/release_notes.md) to view the release notes.