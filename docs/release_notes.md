## DigiNode Tools Release Notes

DigiNode Tools v0.8.1 - 2023-08-15
- Fix: Improve handling of a failed Kubo download - will now completely skip DigiAsset Node install/upgrade in this situation
- Fix: Added workaround for Kubo release glitch - automatically downloads v0.22.0 when v0.21.1 is detected
- Change: Improved one-page setup instructions for Raspberry Pi to make it clearer

DigiNode Tools v0.8.0 - 2023-08-14
- New: Now supports installing a pre-release version of DigiByte Core with the --dgpre flag. Downgrade back to the release version with --dgbnopre
- New: Add --help flag to DigiNode Setup script which describes all the available optional launch flags
- Fix: Improve checks for a failed install of DigiByte Core due to it using a non-standard folder structure. It will now restore the existing version from local backup and restart it.
- Change: Official URL is now diginode.tools. Bash script now uses setup.diginode.tools
- Change: Update Status Monitor to be able to detect a new prerelease/release version of DigiByte Core depending on which is in use
- Change: When quitting Status Monitor, the currently viewed DigiFact remains on the screen.


DigiNode Tools v0.7.4 - 2023-02-26
- More documentation tweaks
- Fix: Fixes to --locatedgb feature
- Add checksum comparison when backing up or restoring wallet.dat to/from a USB stick. This verifies that the wallet file has been copied correctly, during a backup or restore.

DigiNode Tools v0.7.3 - 2023-01-15
- Fix: Display testnet/mainnet selection menu correctly
- Fix: Documentation tweaks and typos
- Fix: Argon One fan installer script, under the 'Extras' menu, should now install correctly

DigiNode Tools v0.7.2 - 2023-01-14
- New: Added step-by-step instructions for setting up a DigiNode on a Raspberry Pi
- Fix: Status Monitor now displays correct sync progress when running testnet
- Fix: Status Monitor now starts correctly when digibyted is not running
- Change: If system RAM exceeds 12Gb, dbcache is now set to 2Gb (aimed at machines with 16Gb RAM)
- Fix: Add workaround for installing DigiNode Tools on Ubuntu

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
- Countless bug fixes and improvements

DigiNode Tools v0.0.4 - 2022-05-10
- Fixed several bugs relating to the Status Monitor being able to check for software updates
- Install URL has changed to diginode-setup.digibyte.help
- Implemented backup feature for prelimanry testing
- Renamed every mention of "DigiNode Installer to "DigiNode Setup"
- WARNING: There is currently a bug with the DigiAsset Node updater that will erase your configuration. I am currently working to fix this.  

DigiNode Tools v0.0.2 - 2021-11-14
- Test Release for the update mechanism

DigiNode Tools v0.0.1 - 2021-11-12
- First test release