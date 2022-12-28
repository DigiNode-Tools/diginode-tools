![DigiNode Logo](images/diginode_logo.png)

# DigiNode Tools

### What's a DigiNode?
A DigiNode is a device that runs a [DigiByte](https://digibyte.org/) Full Node and [DigiAsset Node](https://ipfs.digiassetx.com/) helping to further decentralize the DigiByte ecosystem. 

### What are DigiNode Tools?
DigiNode Tools are a suite of linux bash scripts that make it easy to setup, monitor and manage your DigiNode via the linux command line:
- **DigiNode Setup** - Helps you to install, upgrade, backup and restore your DigiByte and/or DigAsset Node.
- **DigiNode Status Monitor** - Provides a live dashboard to quickly check the status of your DigiNode.

For more information, visit: https://diginode.digibyte.help (website coming soon)

### What do I need to run a DigiNode?
DigiNode Tools should run on most Ubuntu or Debian based systems. See the Compatibility section below.

If you are interested in building your own DigiNode, the recommended setup is a **Raspberry Pi 4 8Gb** with an **SSD** running **Raspberry Pi OS Lite 64-bit**. 

See [here](docs/suggested_hardware.md) for the parts you need.

## Disclaimer

These tools are provided as is. Use at your own risk. Always keep a backup of your DigiByte wallet. 

## Get Started

To get started, run DigiNode Setup by entering the following command in the terminal:

## ```curl -sSL diginode-setup.digibyte.help | bash```

This will perform some system checks before displaying the setup menu that will guide you through the installation process. To customize your setup, see the "Advanced Features" section below.

Note: DigiNode Setup also gives you the option to install DigiNode Tools only (i.e. these scripts). This is so that you can use the DigiNode Status Monitor with your existing DigiByte Node, or want to inspect the scripts before doing a full install. (They will be installed at ~/diginode-tools)

## Support

If you need help, please join the [DigiNode Tools Telegram group](https://t.me/+ked2VGZsLPAyN2Jk). You can also reach out to [@digibytehelp](https://twitter.com/digibytehelp) on Twitter.

## Donations

Thousands of hours have gone into developing DigiNode Tools. If you find these tools useful, kindly make a donation in DGB to support development:

**dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup**

![DigiByte Donation QR Code](images/donation_qr_code.png)

## About DigiNode Setup

![DigiNode Setup](images/diginode_install_menu.png)

DigiNode Setup helps you to setup and manage your DigiNode:

- Intuitively walks you though the process of setting up a DigiByte Full Node, a DigiByte Node ONLY or a DigiAsset Node ONLY. 
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
- **MOTD**: Enable the custom DigiNode MOTD. This displays the DigiNode logo and usage instructions whenever you login via the terminal.
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

- DigiNode Tools should work with most Ubuntu or Debian based systems. A 64-bit OS is required. Both ARM64 and x86_64 hardware are supported. It has been designed with headless operation in mind. 
- A DigiByte Node typically requires ~6Gb RAM but this can be higher during the intial sync. For this reason, a device with at least 8Gb RAM is strongly recommended. 4Gb RAM will work with a SWAP file but performance will be very sluggish - this is fine for testing, but definitely not recommended for long term use. Less than 4Gb RAM is definitely not recommended. (DigiByte Core's memory requirements exceed that of Bitcoin due to multi-algo.)
- A DigiAsset Node requires ~2Gb RAM. If your device has less than 4Gb RAM, you can't run a DigiByte Node, but can still support the network by running a DigiAsset Node.
- A DigiByte Node and DigiAsset Node together often exceed 8GB RAM so a SWAP file is required on any device with 8Gb RAM or less. DigiNode Setup can help configure this for you.
- As of December 2022, the DigiByte blockchain currently requires around 43Gb of disk space. If you are setting up a DigiNode, a minimum 90Gb of free disk space is recommended, to allow for future growth.
- When using a Raspberry Pi 4, booting from an SSD via USB is highly recommended. If you have an 8Gb Pi, it is possible to boot from a microSD card, though this is not recommended for long term use.
- If you are interested in building your own DigiNode using a Raspberry Pi 4, you can find a list of the parts you need [here](docs/suggested_hardware.md).

DigiNode has been tested and known to work with the following systems:

| **Hardware**          | **Operating System**                               | **Notes**                                                                                                   |
|-----------------------|----------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| Raspberry Pi 4 8Gb    | Raspberry Pi OS lite 64-bit (Debian Bullseye)      | This is the recommended configuration. Booting from an SSD, rather than microSD, is highly recommended.     |
| Raspberry Pi 4 8Gb    | Ubuntu Server 22.04 LTS 64-bit                     | Booting from an SSD, rather than microSD, is highly recommended.  Note: There is currently a known issue with this release of Ubuntu that causes the menus to become unresponsive when piping though bash. If you experience this, you may want to try using Raspberry Pi OS instead, or alternatively first clone the DigiNode Tools repo to your home folder, before running the diginode-setup.sh script locally. |
| Raspberry Pi 4 4Gb    | Raspberry Pi OS lite 64-bit (Debian Bullseye)      | Requires swap file. Runs slowly. Fine for testing - not recommended for long-term use.                                                                            |
| x86_64 (Intel/AMD)    | Ubuntu Server 22.04 LTS 64-bit                     | Tested and working on an Intel Core i3-380M laptop with 8Gb RAM.                                            |

## License

DigiNode Tools is licensed under the PolyForm Perimeter 1.0.0 license. TL;DR — You're free to use, fork, modify, and redestribute DigiNode Tools for personal and nonprofit use under the same license. However, you may not re-release DigiNode Tools in an official capacity (i.e. on a custom website or custom URL) in a form which competes with the original DigiNode Tools. This is to ensure that there remains only one official release version of DigiNode Tools. If you're interested in using DigiNode Tools for commercial purposes, such as selling plug-and-play home servers with DigiNode Tools, etc — please contact olly@digibyte.help. For more information read the [Licence FAQ](docs/licence_faq.md). The full licence is [here](LICENCE.md).

## Advanced Features

These features are for advanced users and should be used with caution:

**Unattended Mode:** This is useful for installing the script completely unattended. To run in unattended mode, use the --unattended flag at launch. 
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --unattended``` or
- ```diginode-setup --unattended```

Note: The first time you run DigiNode Setup in Unattended mode, it will create the required diginode.settings file and then exit. If you wish to customize your installation further, you can edit this file before proceeding. It is located here: ~/.digibyte/diginode.settings
If you want to skip this step, and simply use the default settings, include the --skipcustommsg flag:
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --unattended --skipcustommsg``` or
- ```diginode-setup --unattended --skipcustommsg```

**DigiAsset Node ONLY Setup:** If you have a low spec device that isn't powerful enough to run DigiByte Node, you can use the ```--dganodeonly``` flag to setup only a DigiAsset Node. Using this flag bypasses the hardware checks required for the DigiByte Node. A DigiAsset Node requires very little disk space or memory and should work on very low power devices. If you later decide you want to install a DigiByte Node as well, you can use the ```--fulldiginode``` flag to upgrade your existing DigiAsset Node setup. This can also be accessed from the main menu.
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --dganodeonly``` or
- ```diginode-setup --dganodeoonly```

**Reset Mode**: This will reset and reinstall your current installation using the default settings. It will delete digibyte.conf, diginode.settings and main.json and recreate them with default settings. It will also reinstall DigiByte Core and the DigiAsset Node. IPFS will not be re-installed. Do not run this with a custom install or it may break things. For best results, run a standard upgrade first, to ensure all software is up to date, before running a reset. Software can only be re-installed if it is most recent version. You can perform a Reset via the DigiNode Setup main menu by entering ```diginode-setup```. You can also use the --reset flag at launch.
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --reset``` or
- ```diginode-setup --reset```

**Skip OS Check:** The --skiposcheck flag will skip the OS check at startup in case you are having problems with your system. Proceed with caution.
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --skiposcheck``` or
- ```diginode-setup --skiposcheck```

**Skip Update Package Cache:** The --skipupdatepkgcache flag will skip trying to update the package cache at launch in case you are do not have permission to do this. (Some VPS won't let you update.)
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --skipupdatepkgcache``` or
- ```diginode-setup --skipupdatepkgcache```

**Uninstall:** The --uninstall flag will uninstall your DigiNode. Your DigiByte wallet will be kept. This can also be accessed from the main menu.
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --uninstall``` or
- ```diginode-setup --uninstall```

**Verbose Mode:** This provides much more detailed feedback on what the scripts are doing - useful for troubleshooting and debugging. This can be set using the ```--verboseon``` flags.
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --verboseon```
- ```diginode-setup --uninstall```

**Manually Locate DigiByte Core:** If you wish to use the DigiNode Status Monitor with your existing DigiByte Node (i.e. One not setup with DigiNode Tools), and the startup checks are not able to locate it automatically, use the ```--locatedgb``` flag at launch to manually specify the folder location.
- ```diginode --locatedgb```

**Developer Mode:** To install the development branch of DigiNode Tools, use the ```--dgntdev``` flag at launch. The ```--dgadev``` flag can be used to install the development branch of the DigiAsset Node. WARNING: These should only be used for testing, and occasionally may not run.
- ```curl -sSL diginode-setup.digibyte.help | bash -s -- --dgntdev --dgadev``` or
- ```diginode-setup --dgntdev --dgadev```

## Release Notes

DigiNode Tools v0.7.1 - 2022-12-28
- Add a custom DigiNode MOTD that displays when you login to the machine via the terminal. It includes the DigiNode logo and brief usage instructions to remind the user of the commands to launch 'DigiNode Setup' and 'DigiNode Status Monitor'.
- During the first install, the user is asked whther or not they want to install the DigiNode MOTD.
- The existing system MOTD is backed up to ~/.motdbackup and restored from there if you later uninstall the DigiNode MOTD
- The DigiNode MOTD can also be installed/removed via the main menu.

DigiNode Tools v0.7.0 - 2022-12-25
- Add new menu driven options to choose between running a DigiByte mainnet and testnet node
- DigiByte network can also be specified via diginode.settings when performing an unattended install
- Status Monitor now displays when it is monitoring a DigiByte testnet node
- DigiNode Setup menu now lets you easilly switch between running a DigiByte testnet and mainnet nodes. It will also prompt you to delete the blockchain data for the unused chain.
- When running a testnet node, it will now offer to change the hostname to diginode-testnet. This is to make it easy to run two DigiNodes on the same network - one on mainnet and the other on testnet.
- Switching between running mainnet and testnet, also changes the rpcport if it using the default one
- If running testnet, IPFS with will now automatically switch to using port 4004. (By default it uses 4001.) This is to prevent two DigiNodes - one mainent and one testnet - running on the same network, from conflicting with each other. (Note: If the IPFS config uses a port that differs from 4001 or 4004 the port will remain unchanged.)

DigiNode Tools v0.6.7 - 2022-12-15
- Updated Recomended Hardware documentation
- Add testnet flag to digibyte.conf

DigiNode Tools v0.6.6 - 2022-12-12
- Fix bug when running unattended update from DigiNode Status Monitor
- Improvements to this documentation.

DigiNode Tools v0.6.5 - 2022-08-20
- Fix creating a swap file in Debian 11 

DigiNode Tools v0.6.4 - 2022-08-12  
- Status Monitor: Bring back the ability to press Q to Quit, in case Ctrl-C doesn't work. 
- Lots of bug fixes and formatting issues

DigiNode Tools v0.6.3 - 2022-08-10
- DigiNode Setup now prompts the user to create a swap file if RAM + SWAP <12Gb. This is to ensure that DigiByte Nodes and DigiAsset Node can work smoothly on the same device. This solves a problem of DigiByte Core running out of memory on a 8Gb device that is also running a DigiAsset Node.
- Automatic swap file creation is now supported on Debian as well as Ubuntu. The recommended total memory (swap + ram) has been increased from 8Gb to 16Gb. This means if you have a 8Gb device it will recomend creating an 8Gb swap file.
- Status Monitor: Swap Usage now shows how much swap is free.

DigiNode Tools v0.6.2 - 2022-08-07
- Fix: Improve Status Monitor auto-quit instructions
- Fix: Hide key press codes when scrolling in status monitor
- Fix: Renable port test when DigiByte port changes

DigiNode Tools v0.6.1 - 2022-08-06
- DigiNode Tools now requires DigiAsset Node v4. Until v4 is released, it will now install the development branch automatically. (DigiAsset Node v3 does not work correctly with Kubo IPFS, but this issue has been fixed in v4 development version.)
- Fix DigiByte port tester to not display an error  when the testing site is down or busy.
- DigiByte port test is now automatically re-enabled if the port has changed since it last successfully passed the test.
- Port tester can now handle using a non-standard listening port (i.e. not port 12024)

DigiNode Tools v0.6.0 - 2022-08-05
- Status Monitor - Add DigiByte port test developed by Renzo Diaz for the DigiByte Alliance. This makes it easy to quickly test if port 12024 is open. It queries an external API then tests if your port is open.
- DigiNode Setup - Added uPnP Menu which asks to enable/disable UPnP for DigiByte Core and IPFS during first install. In unattended mode its gets the values from diginode.settings. Once installed, you can enable/disable UPnP via the main menu.
- DigiNode Setup - The user is now asked if they want to enable the IPFS Server profile when first installed. The server profile disables IPFS local host discovery - ueful when running a DigiAsset Node on a server with a public IP address. In unattended mode its gets this value from diginode.settings. 
- DigiNode Setup - Add option to delete the ~/.jsipfs folder when uninstalling DigiAsset Node
- Status Monitor - DigiByte 'starting up' messages are now in yellow to indicate a temporary issue
- Status Monitor - Improve detection of when DigiNode internet connection is online/offline
- Status Monitor - Improve startup messaging. It now displays each step that is being processed when running though the status loop for the first time. It shows that it is actually doing something, rather than having the user stare at a frozen screen.
- Status Monitor - To ovoid putting extended strain on the server, the Status Monitor now quits automatically after 20 minutes. The duration is now set in minutes rather than seconds. A message is now displayed when it auto-quits.

DigiNode Tools v0.5.6 - 2022-08-01
- New: Status Monitor now quits automatically after one hour by default
- New: When using Unattended mode, you can now use the --skipcustommsg to skip the option to customize diginode.settings at first run.
- New: Status Monitor now includes if there is a payout address for the DigiAsset Node

DigiNode Tools v0.5.5 - 2022-07-31
- Fix: The Status Monitor can now better detect if the DigiAsset Node is running.
- New: Status Monitor will now detect if the DigiAsset Node goes offline and when it comes back online again.
- New: Status Monitor IPFS status now shows in yellow when starting up etc.
- New: Kubo API URL gets added to main.json when Kubo is installed and removed when it is deleted. DigiAsset Node restarts when Kubo is removed to ensure it switches to using JS-IPFS.
- Updated README

DigiNode Tools v0.5.4 - 2022-07-30
- Fix: Improvements to the DigiAsset Node upgrade process - fix rare incidence when PM2 processes get duplicated
- New: Add IPFS URL to main.json template so DigiAsset Node will use Kubo rather than js-IPFS
- New: Status Monitor now display IPFS status in red if the port is blocked
- Fix: DigiAsset Node blocked port issue seems to have been resolved
- New: Add new 'Extras' menu with an option to install the fan softwrare for the Argon ONE Case for the Raspberry Pi 4

DigiNode Tools v0.5.3 - 2022-07-29
- Fix: Improve detection for when to add Nodesource PPA. It will now be re-added automatically if the current NodeJS version is < 16.
- Fix: When running DigiNode Setup locally, upgrading from DigiAsset Node to full DigiNode now works as intended.
- Fix: DigiAsset Node will now only be installed if NodeJS is at least v16

DigiNode Tools v0.5.2 - 2022-07-27
- New: DigiByte Core port 12024 is now added to the port test flow
- New: Port test(s) now get hidden after the ports are detected to be open. The IPFS port is retrieved directly from the DigiAsset Node console.
- New: Port test gets re-enabled automatically when launching the Status Monitor if the External IP has changed. It also gets renabled if the IPFS port has changed.

DigiNode Tools v0.5.1 - 2022-07-26
- Fix: Local DGNT branch now detected correctly

DigiNode Tools v0.5.0 - 2022-07-26
- New: DigiNode Status Monitor will now work with only a DigiAsset Node (i.e. DigiByte Core is not installed or not running).
- New: Add IPFS Port test to Status Monitor (this is under testing for the moment - there is a known issue with the IPFS port)
- New: Add ```--locatedgb``` flag to the Status Monitor to let you specify the location of your existing DigiByte install folder.
- New: While checking an existing DigiAsset Node, if there is no update available, but PM2 is not running for some reason, it will be restarted

DigiNode Tools v0.4.5 - 2022-07-25
- Change: Wallet balance will now only display if the balance is greater than 0.
- Change: Backup reminder will only be displayed if the wallet balance is greater than 0.
- Change: Improve messaging when restoring a DigiByte wallet from backup
- Change: Hide cloud IP in closing messages if it is the same as the internal IP 

DigiNode Tools v0.4.4 - 2022-07-24
- New: Add option to display the wallet balance in the Status Monitor. You can choose not to display this by setting the SM_DISPLAY_BALANCE variable in diginode.settings
- New: Status Monitor now displays the disk usage percentage in red if it is 80% or over
- New: Add check to make sure the DigiByte Core download completes successfully.

DigiNode Tools v0.4.3 - 2022-07-23
- New: Add ```--skipupdatepkgcache``` flag for skipping package update check at startup (some VPS won't let you update)
- Fix: When performing a DigiAsset Node Only setup, it now checks for NodeJS
- Assorted fixes and improvements to make it easier to run DigiNode Tools on a VPS

DigiNode Tools v0.4.2 - 2022-07-23
- New: Current block count in Status Monitor now has thousands seperated by commas
- Fix: Change mentions of 'go-ipfs' in Github download to 'kubo' - downloads have been renamed. Same with the install folder.
- Fix: If Kubo download fails (maybe the download URL has changed?), restart the existing version and exit. This ensures that a change in the download URL will not break existing installs.

DigiNode Tools v0.4.1 - 2022-07-17
- Fix: Improve DigiByte locate menu during Status Monitor startup

DigiNode Tools v0.4.0 - 2022-07-17
- Fix: Uninstall now prompts to remove DigiByte Core and the DigiByte blockchain only if they are present
- Change: Rewrote closing messages to be clearer
- Fix: Lots of formatting problems and other bugs

DigiNode Tools v0.3.12 - 2022-07-17
- New: Use the new ```--dganodeonly``` flag to install only the DigiAsset Node without a DigiByte Node. Maybe you have a low spec device that isn't powerful enough to run a DigiByte Node? You can now run only a DigiAsset Node on it. It's a great way to support the DigiByte blockchain, if you can't run a full node.

DigiNode Tools v0.3.11 - 2022-07-16
- New: If an "unofficial" DigByte Node is detected at launch (i.e one not originally setup using DigiNode Tools), and DigiNode Tools is installed, it now displays a menu offering to either upgrade DigiNode Tools or uninstall it. This is so you can upgrade the Status Monitor with your own DigiByte Node.

DigiNode Tools v0.3.10 - 2022-07-15
- New: The Status Monitor will now prompt the user for the absolute location of their DigiByte Core install folder if it cannot locate it. This should make it easier to use the Status Monitor with an existing DigiByte Node that wasn't set up using DigiNode Setup.

DigiNode Tools v0.3.9 - 2022-07-15
- New: Add menu option to install DigiNode Tools ONLY. This is to make it easier to use the Status Monitor with an existing DigiByte Node. It also lets you run the DigiNode Setup script locally, which gives you the opportunity to look at what it does before you run it. Always install it from the official Github repository.

DigiNode Tools v0.3.8 - 2022-07-14
- New: Auto-upgrade diginode.settings file whenever there is a new release. This will make it significantly easier to add new features to DigNode Tools in the future, as diginode.settings can now be upgraded to support them. Up till now you would likely have had to delete diginode.settings whenever there was a significant upgrade to DigiNode Tools.

DigiNode Tools v0.3.7 - 2022-07-13
- New: Create new diginode.settings.new file whever there is a new release. This is to test the update mechanism for upgrading diginode.settings.

DigiNode Tools v0.3.6 - 2022-07-13
- New: Add detection system to deduce whether DigiNode Setup is being run locally or remotely.
- New: Preliminary tests for a new feature to upgrade the diginode.settings file whenever there is a new release. This is to allow for adding new features in the future that require changes to diginode.settings

DigiNode Tools v0.3.5 - 2022-07-11
- Add more screenshots to the README
- Documentation updates
- Update several DigiFacts

DigiNode Tools v0.3.4 - 2022-07-10
- New: Add reminder to install system updates if there are any
- Change: DigiNode dependencies are now installed before DigiNode Setup begins. Avahi-daemon is still installed just before the hostname change.

DigiNode Tools v0.3.3 - 2022-07-09
- Fix: Don't restart digibyted before wallet backup if it is already running
- Fix: Memory/swap values in Status Monitor should now display correctly

DigiNode Tools v0.3.2 - 2022-07-09
- Fix: Formatting for Disk Usage in Status Monitor
- Fix: Formatting for 'DigiAsset Node is not running' message in Status Monitor
- Fix: PM2 process detection now works correctly

DigiNode Tools v0.3.1 - 2022-07-09
- New: DigiNode Tools now work on x86_64 architecture so you can use it to setup a DigiNode on PC hardware. (Please help test!)
- Change: Rename Go-IPFS to Kubo (the name has been changed)
- Change: IPFS Updater utility is no longer used to install Kubo (formerly Go-IPFS). It is now installed by DigiNode Setup itself.
- Fix: Hide temperature in Status Monitor if it cannot be read from the system
- Fix: In Status Monitor, hide DEVICE row if the device is unknown
- Fix: Improve the scripts ability to detect if DigiAsset Node is installed and/or running.

DigiNode Tools v0.2.5 - 2022-07-07
- Fix: --skiposcheck flag now works as expected
- New: Improve documentation by adding equipment suggestions for building your own DigiNode

DigiNode Tools v0.2.4 - 2022-07-01 
- Fix: Installation now cancels if Go-IPFS fails to install. There is a recurring problem with the install files not downloading which may be a probelm with their servers. Typically, if you keep retrying it will eventually work.
- Fix: Hide swap status in status monitor if the swap is tiny (i.e. around 1 Mb)
- Fix: Correct error display if IPFS install fails

DigiNode Tools v0.2.3 - 2022-07-01
- Fix: Start IPFS daemon during an update if it installed but not currently running (perhaps due to a failed previous install)
- Fix: If you launch Backup/Restore from the menu, and then run Update, the script now performs as expected. Before it would loop back and continue backup/restore from where you had stopped halfway though.
- Fix: Formatting of update display in status monitor

DigiNode Tools v0.2.2 - 2022-06-29
- Fix DigiNode Tools update checker

DigiNode Tools v0.2.1 - 2022-06-29
- Add Restore feature - you can now restore your DigiByte wallet and/or DigiAsset Settings from a previously created USB backup.
- You can now cancel inserting a USB stick by pressing a key
- Change Status Monitor timers to use unix time to fix a bug where they don't get triggered correctly
- Status monitor now displays more detail while waiting for DigiByte daemon to finish starting up
- Version number has been bumped to reflect new features added
- Note: Due to changes in how the Status Monitor tracks time, you may need to delete your existing diginode.settings file before use

DigiNode Tools v0.0.9 - 2022-05-27
- Fixes for the DigiNode Tools version checker
- Pushed out several releases to test its ability to detect and install new versions.

DigiNode Tools v0.0.8 - 2022-05-26
- Another attempt to fix DigiNode Tools verion checks

DigiNode Tools v0.0.7 - 2022-05-26
- Another attempt to fix DigiNode Tools version checks

DigiNode Tools v0.0.6 - 2022-05-26
- Reboot is hopefully no longer required after first install
- diginode.settings variables now get reset during an uninstall
- backup reminder is displayed until you have made one
- lots of fixes and improvements to backup function

DigiNode Tools v0.0.5 - 2022-05-19
- USB Backup feature now backs up DigiAsset settings as well as DigiByte Wallet
- DigiAsset Settings are backed up locally when uninstalling, if desired. This fixes the update bug mentioned in v0.0.4
- Fixes to diginode.settings to better store variables
- Any changes made to the RPC credentials (user/password/port) in digibyte.conf are now automatically updated in the DigiAssets settings file (main.json) file when running an 'Update' from the DigiNode Setup menu.
Countless bug fixes and improvements

DigiNode Tools v0.0.4 - 2022-05-10
- Fixed several bugs relating to the Status Monitor being able to check for software updates
- Install URL has changed to diginode-setup.digibyte.help
- Implemented backup feature for prelimanry testing
- Renamed every mention of "DigiNode Installer to "DigiNode Setup"
- WARNING: There is currently a bug with the DigiAsset Node updater that will erase your configuration. I am currently working to fix this.  

DigiNode Tools v0.0.2 - 2021-11-14
- Test Release for the update mechanism

DigiNode Tools v0.0.1 - 2021-11-12
- First text release
