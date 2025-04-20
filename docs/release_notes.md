## DigiNode Tools Release Notes

DigiNode Tools v0.11.1 - 2025-04-20
- Change: Default auto quit duration for the DigiNode Dashboard has been changed to 24 hours (1440 minutes).
- Change: Mempool bytes are hidden on narrower terminal windows to make the display cleaner.
- Fix: When running a Dual Node, the Testnet listening port now displays correctly in the Dashboard while the node is starting up. (It was blank before)
- Fix: Right border for Connections row in dashboard now fits better.

DigiNode Tools v0.11.0 - 2025-04-19
- New: DigiNode Dashboard now has a brand new port tester built for DigiNode Tools. It can test nodes at IPv4, IPv6 and onion addresses. The port tester is also available for anyone to use at: https://diginode.tools/digibyte-port-tester/
- New: DigiNode Dashboard now optionally displays the mempool data for each node. By default, Mempool data is displayed whenever transactions enter the mempool and is hidden if there are no transactions seen for 30 seconds. This way mempool data is shown only when there is mempool data to show. You can enable/disable displaying the mempool data by editing the variables SM_DISPLAY_MAINNET_MEMPOOL and SM_DISPLAY_TESTNET_MEMPOOL in diginode.settings. (Enter ```diginode --settings```). SM_MEMPOOL_DISPLAY_TIMEOUT can be used to set the timeout duration.
- New: DigiNode Dashboard now displays the incoming and outgoing connections for your DigiByte node.
- Change: peers.dat is now deleted each time you switch between running a Tor node and a clearnet node. This ensures the node starts with a fresh list of peers to connect to.
- Change: Add message to Dashboard about DigiAsset Core support. Adding support for DigiAsset Core is not possible at this time due to a bug in DigiByte Core v8.22.x.
- Change: DigiNode Dashboard autoquit timer is now much more accurate.
- Fix: Blockchain sync progress is now reset when the blockchain data is deleted or the network is changed.
- Fix: Fahrenheit temperature is now displayed correctly.
- Fix: If DigiFacts web service is down, errors are now handled more gracefully.
- Fix: Spelling error in DigiFact Tip.
- Fix: DigiByte Port tests now get automatically reenabled if enabling/disabling Tor.

DigiNode Tools v0.10.10 - 2025-02-24
- Fix: The time online for the Testnet node in the Dashboard now displays in UTC instead of local time
- Fix: Fixed a showstopping bug that prevented DigiByte Core from being successfully upgraded from a pre-release to the latest release. Somehow I missed this till now. Apologies!

DigiNode Tools v0.10.9 - 2025-02-12
- New: Dashboard now displays the disk space used by the running blockchain
- New: DigiNode CLI and Dashboard now display the version number at launch
- Fix: When running a Dual Node, the secondary Testnet node now gets shutdown correctly before performing an uninstall
- Fix: Blockchain data is now uninstalled fully, when switching between running mainnet and testnet nodes (and vice versa)
- New: Uninstaller now prompts to uninstall Regtest and Signet blockchain data if present

DigiNode Tools v0.10.8 - 2025-02-11
- Change: Update the DigiFacts web service URL which has changed to: https://digifacts.diginode.tools. The DigiFacts Github repo has moved to: https://github.com/DigiNode-Tools/DigiByte-DigiFacts-JSON

DigiNode Tools v0.10.7 - 2025-02-08
- Fix: ```diginode --dgbpeers``` and ```diginode --dgb2peers``` should now display the onion peers correctly.

DigiNode Tools v0.10.6 - 2025-02-07
- New: Rewritten Raspberry Pi hardware checker. It should now automatically identify all Raspberry Pi hardware - including all recent models of the Raspberry Pi 5 and any future models yet to be released.
- New: Can now identify when a DigiNode is booting off a PCIe NVME SSD on the Raspberry Pi 5.
- New: DigiNode has now been fully tested on the Raspberry Pi 5 8Gb with a PCIe NVME SSD. Everything works as intended. All Raspberry Pi 5 models with 4Gb RAM should be supported. 8Gb RAM or more is strongly recommended. Please post a message in the Telegram group if you encounter any issues: https://t.me/DigiNodeTools

DigiNode Tools v0.10.5 - 2025-02-06
- New: DigiNode Setup now displays the version number at launch. This should make troubleshooting easier by making it much easier to tell which version you are currently running.
- New: The --listwallets flag displays the currently installed wallets. This is part of a planned suite of wallets tools. (May not work yet.)
- Change: Replace X support links for Bluesky as the account is no longer in use

DigiNode Tools v0.10.4 - 2025-02-05
- New: Added support for DigiByte Core v8.22.1

DigiNode Tools v0.10.3 - 2024-06-03
- New: The onion address(es) for your DigiByte mainnet and/or testnet node(s) are now displayed in DigiNode Dashboad, when available.

DigiNode Tools v0.10.2 - 2024-06-09
- Fix: Improve detecting if Tor service is configured and running
- Fix: User account now gets added to the 'debian-tor' user group to so the Tor control port works correctly

DigiNode Tools v0.10.1 - 2024-06-09
- Fix: Reenable terminal cursor after quitting dashboard
- Fix: Nodes are now automatically restarted if the Tor settings are appended and Tor is enabled
- Fix: Bug appending Tor settings to digibyte.conf

DigiNode Tools v0.10.0 - 2024-06-08
- New: Tor support! - Your DigiByte nodes can now run over the Tor network for better privacy. You can switch your DigiByte mainnet and/or testnet node to run on Tor via the main menu.
- Change: ```--dgbpeers``` and ```--dgb2peers``` now also displays the onion peers, if available.
- Change: The flag ```--dgbcfg``` is now ```--dgbconf```. The flag ```--dgntset``` is now ```--settings```. This should hopefully make them easier to remember.
- Fix: Bug that prevents the mainnet and testnet node from starting up if the user installs a Dual Node on a clean system.
- Fix: Error in Dashboard when running only a Testnet node
- Fix: Error loading CPU usage at Dashboard startup

DigiNode Tools v0.9.13 - 2024-05-25
- Change: Remove DigiAsset Node software. This is temporary. The legacy DigiAsset Node software has not been functioning correctly for some time and has therefore been retired. The release will automatically purge it from your DigiNode. Support for the new DigiAsset Core, which is a complete rewrite of the DigiAsset software, will be added in an upcoming release.
- Fix: Better detection in the Dashboard for when the DigiNode is offline.

DigiNode Tools v0.9.12 - 2024-04-10
- Fix: Hide displayed download progress when checking for DigiByte Core update at Dashboard launch
- New: Updated Raspberry Pi detection to identify newer Pi 4, Pi CM4, Pi 400 and Pi 5 models.
- New: DigiNode Tools must be running the latest version to install the other updates. This helps to avoid any install changes between versions.

DigiNode Tools v0.9.11 - 2024-04-02
- New: Add support for DigiByte Core v8.22.0-rc4

DigiNode Tools v0.9.10 - 2024-03-29
- Fix: Testnet peers now sort alphabetically as well when using ```--dgb2peers```.
- Change: Uninstalling blockchain data now deletes everything except the wallet (previously it kept the banlist, mempool, peers etc.)
- Change: DigiNode Tools Github repo has moved to the new DigiNode Tools org on Github. All links have been updated to reflect this.

DigiNode Tools v0.9.9 - 2024-02-04
- Fix: Sync progress in DigiNode Dashboard is now correctly calculated.
- Fix: Error detecting avahi-daemon in Dashboard.
- Fix: No longer prompts to overwrite DigiFacts JSON.
- Change: Remove testnet / dual node warning message.

DigiNode Tools v0.9.8 - 2024-02-03
- Fix: DigiNode Tools now correctly installs DigiByte Core 8.22.0-rc3 that has just been released.

DigiNode Tools v0.9.7 - 2024-02-03
- New: When installing/upgrading DigiByte Core the script now looks for a sha256 hash on the DigiNode Tools website and only allows the install/upgrade to proceed if it is available. Once downloaded, the new binary is checked against the hash to make sure that it has not been tampered with. This change significantly improves DigiNode security providing protection in the event that the DigiByte Core repo is compromised. In an emergency you can bypass these checks using the ```--skiphash``` flag though this is not recommended.
- New: Users must now agree to the software disclaimer before using DigiNode Tools. Continued use of DigiNode Tools constitutes you agree to the terms in the disclaimer. You will be asked to agree each time there is a new release.
- Change: ```--dgbpeers``` and ```--dgb2peers``` now list peers alphabetically.
- Fix: In DigiNode Dashboard, if the external and internal IP addresses are both the same (i.e. we are on a server with a public IP), then it now only shows the external IP.
- Fix: In DigiNode Dashboard, an error no longer displays if there is no IP6 address.
- Change: In DigiNode Dashboard, "System Time" and "Online Since" are now displayed in UTC regardless of the server location or the user's local time. This makes it easier to compare the current state of differnet nodes regarldess of where they are located.

DigiNode Tools v0.9.6 - 2024-01-19
- New: The DigiNode Tools website is finally live: [https://diginode.tools](https://diginode.tools)
- Change: Most of the project documentation has been moved from Github to the DigiNode Tools website.
- Fix: Individual CPU usage in DigiNode Dashboard is correctly aligned regardless of percentage.

DigiNode Tools v0.9.5 - 2024-01-14
- New: Use the ```diginode --dgb2log``` flag to view the DigiByte Node testnet log while running a Dual Node.
- Fix: Downgrading from a DigiByte pre-release back to the latest release now works as expected.
- Change: 'Upgrade Available' dialog now shows exactly what will be upgraded
- Fix: Passwordbox inputs now work as expected

DigiNode Tools v0.9.4 - 2024-01-12
- New: DigiFacts are now updated once per hour from the DigiByte DigiFacts - JSON Web Service. You can find it [here](https://digifacts.digibyte.help/?help). Developers are encouraged to use the DigiFacts web service in their DigiByte projects. You can help contribute new DigiFacts,improve existing ones, translate them into additional languages, or donate to the translation fund. Learn more [here](https://github.com/saltedlolly/DigiByte-DigiFacts-JSON).
- New: Use the ```diginode --porttest``` flag to manually re-enable the DigiByte Node and DigiAsset Node port tests, if needed.
- Fix: Switch from using whiptail menus to dialog menus. This is to get around the Debian bug that is causing the menus to be unresponsive at first launch - key presses do not work and it is impossible to proceed. This bug affected whiptail menus - dialog is not affected - and is triggered when piping through bash. By switching to dialog we bypass the issue, and no longer need the Ubuntu workaround.
- Fix: Web UI URL in DigiNode Dashboard now gets split across two lines when required, if there are two URLs.
- Change: Remove support for running a DigiAsset Node ONLY. [DigiAsset Core](https://github.com/DigiAsset-Core/DigiAsset_Core), which will soon replace the current DigiAsset Node software, requires a DigiByte Node to function. It will no longer be possible to run a DigiAsset Node without a DigiByte Node so this option has been removed. You can learn more about DigiAsset Core [here](https://digiassetcore.digiassetx.com/).
- Change: If there are multiple updates available, DigiNode Setup now lets you install them individually.
- Change: CPU usage in DigiNode Dashboard is now displayed as a whole number.
- Change: Remove digifact78 from digifacts.json as this describes DigiNode Tools itself.
- Change: Removed Ubuntu workaround as this is no longer required
- Change: Rename "Kubo IPFS" to "IPFS Kubo" to match official IPFS naming

DigiNode Tools v0.9.3 - 2023-10-26
- Fix: DigiNode Dashboard now installs sysstat if not present
- Fix: Replace mentions of DigiNode Status Monitor with DigiNode Dashboard

DigiNode Tools v0.9.2 - 2023-10-23
- Fix: Dashboard spacing when there is an update available in the Software section
- Fix: Don't check the disk usage of IPFS if it is not present.
- Fix: Permissions issue with digifacts.json file

DigiNode Tools v0.9.1 - 2023-10-23
- Fix: Error detecting testnet disk usage when no testnet4 folder exists.
- Fix: Error with DigiByte update checker when version numbers are the same. It should hopefully be able to correctly identify updates now.
- Fix: Detecting public/external IP6 address as detected by icanhazip.com
- Fix: Hide digifacts if they are not present due to a failed download or other error

DigiNode Tools v0.9.0 - 2023-10-22
- New: Introducing "DigiNode Dashboard" with Dual Node support! The old Status Monitor has been completely redesigned and rewritten from the ground up which called for a new new name - goodbye DigiNode Status Monitor, hello DigiNode Dashboard! It now resizes automatically to fit the width of the terminal, increasing or decreasing the information density based on the space available. It also now displays the CPU stats and other useful data. Most importantly it also has support for a Dual Node - displaying data from both your mainnet and testnet nodes at the same time.
- New: The DigiFacts are now automatically downloaded from the new "DigiByte-DigiFacts-JSON" repository on Github. The DigiFacts have been formatted into a JSON file so that anyone in the DigiByte community can use them in their own projects. More information [here](https://github.com/saltedlolly/DigiByte-DigiFacts-JSON)
- New: Added ```diginode --dgbpeers``` flag to display the current DigiByte peers. User ```--dgb2peers``` for the secondary textnet neode when running a Dual Node.
- New: Added ```diginode --rpc``` flag to display the current RPC credentials for the DigiByte Node. These were previously displayed in the Status Monitor but for privacy reasons they have been removed. This command saves you from having to look them up in digibyte.conf. 
- Fix: New improved update checker for DigiByte Core. It can now handle comparing release versions to pre-release versions, including test variants (e.g. 8.22.0-rc3-faststart), to detect if there is an update available. If you are creating your own test variants, each one should be in its own folder in the home folder (e.g. ~/8.22.0-rc3-faststart). Within this folder you need to also create a hidden file called .prerelease and inside that file include a variable assignment for the current version (e.g. DGB_VER_LOCAL="8.22.0-rc3-faststart"). Finally you need to create a symbolic link in the home folder called 'digibyte' that points at the test variant folder. Be sure to delete the existing 'digibyte' symbolic link first, if it already exists.
- Fix: DigiNode Dashboard no longer flickers as it was prone to do in all previous versions.
- Fix: DigiNode Dashboard no longer gets duplicated down the screen! This used to happen occasionally when using the mouse with the terminal particularly on macOS. Clicking on the terminal window would could the Status Monitor to get duplicated down the terminal and the only way to solve it was to scroll down all the way to the bottom. It was an infuriating bug that has been there since the beginning. Hopefully it is now gone for good.
- Fix: Windows users should now see colors in DigiNode Dashboard. If you don't, please download [Windows Terminal from the Microsoft store](https://apps.microsoft.com/detail/9N0DX20HK701). This is the recommended terminal software for DigiNode users on Windows. 

DigiNode Tools v0.8.10 - 2023-10-08
- New: Add support for new DigiByte port tester developed by @JongJan88
- New: More backend work in preperation for adding Dual Node support in the Status Monitor
- Fix: Use of an recognised --flag at launch will now display an error and quit

DigiNode Tools v0.8.9 - 2023-09-29
- New: DigiNode Tools can now set up a Dual Node - i.e. Running a DigiByte mainnet node and testnet node simultaneously on the same device. You can also switch between them from the DigiNode Setup menu.
- Fix: Switching between chains and enabling/disabling uPnP from the DigiNode Setup should now work correctly again. v0.8.7 introducted some bugs which hopefully are now solved.
- IMPORTANT: Running a DigiByte testnet node or a Dual Node should only be attempted with DigiByte Core 8.22.0-rc3 or later, which is not yet released at time of writing. There is a bug in earlier versions of DigiByte Core, that causes the testnet chain to take many hours to start up - sometimes 24 or more. Running it on a Raspbeery Pi will not work. A more powerful system will get there eventually but will still take many hours to start up. In short, it is advisable to wait for the upcoming release before trying these.
- Known issues: The Status Monitor does not yet support displaying the status of the testnet node when running a Dual Node. This will be added in a future release.

DigiNode Tools v0.8.8 - 2023-09-10
- Fix: Roll back using IPFS lowpower mode with a Raspberry Pi. It seems to be causing performance issues.
- Fix: Switch back to using Node.js 16. There are problems with the web UI in Node.js 18 and 20.

DigiNode Tools v0.8.7 - 2023-09-09
- New: Add new sections in digibyte.conf for [main], [test], [regtest] and [signet]. These are required in DigiByte v8.
- New: DigiNode Setup can now automatically upgrade an existing digibyte.conf to add any missing sections and/or required variables. If it is unable to do it automatically, it instructs the user how to do this manually. The user has the option to simply delete their existing digibyte.conf, and have the script recreate based on the new template.
- New: Status Monitor now recognizes if a DigiByte Node is is running a regtest or signet chain and displays relevant status information.
- New: Upgrade Status Monitor so that it can display the correct listening port, maxconnection count and RPC credentials from digibyte.conf depending on which chain we are running, and which section of digibyte.conf the values are in.
- New: Status Monitor startup checks can now detect if digibyted has failed and display the error.
- New: Add ```--help``` flag to DigiNode Status Monitor. To view a list of the optional flags, enter: ```diginode --help```
- New: Status Monitor now displays the listening port and upnp status. It disappears once it knows that the port is being forwarded correctly.
- New: Uninstaller now lets you uninstall Node.js. You must uninstall the DigiAsset Node first.
- Fix: Improve ability to recognize system RAM on an unknown Raspberry Pi model.
- Fix: Node.js installer now uses the new Nodesource repositories.
- Fix: Repair misalligned column in Status Monitor when swap size is double figures.
- Fix: IPFS cat command now attempts to download the new readme file to test your install. The old one was no longer available, so would always fail.
- Fix: DigiNode Setup now correctly runs Rasperry Pi checks unless we are in DigiAsset Node ONLY Mode.
- Change: Status Monitor 15 second timer now runs every 10 seconds.
- Change: Improve formatting of wallet balance in status monitor.
- Change: IPFS now uses the lowerpower profile on a Raspberry Pi

DigiNode Tools v0.8.6 - 2023-08-27
- Fix: UPnP menu now displays current DigiByte port correctly
- Change: DigiAsset Node node now displays block height with commas so it is easy to read

DigiNode Tools v0.8.5 - 2023-08-26
- Fix: Bug with ```--skippkgupdate```

DigiNode Tools v0.8.4 - 2023-08-21
- Fix: Rework the process of upgrading from running a DigiAsset Node ONLY to a FULL DigiNode. Now works correctly when using the ```--dgbpre``` flag.

DigiNode Tools v0.8.3 - 2023-08-21
- Change: More documentation improvements
- Change: Add ```--help``` tip to MOTD
- Fix: Minor bug when installing MOTD
- Fix: Status Monitor now displays "Block Height" from the DigiAsset Node console. I previously did not include this simply to save space, but I have recently discovered that this sometimes displays important error messages. It has also a revealed a bug with the DigiAssets Node which DigiAssetX is working to fix.

DigiNode Tools v0.8.2 - 2023-08-18
- Change: Switch Twitter social links to use @dignodetools instead of @digibytehelp. Also, add additional links to Bluesky account and Telegram group.
- Change: Now displays web UI IP address alongside hostname. For various reasons, sometimes the hostname does not work when used in the URL, so best to have a backup option.
- Change: Lots of documentation improvements.
- Fix: Several minor bug fixes

DigiNode Tools v0.8.1 - 2023-08-15
- Fix: Improve handling of a failed Kubo download - will now completely skip DigiAsset Node install/upgrade in this situation
- Fix: Added workaround for Kubo release glitch - automatically downloads v0.22.0 when v0.21.1 is detected
- Change: Improved one-page setup instructions for Raspberry Pi to make it clearer

DigiNode Tools v0.8.0 - 2023-08-14
- New: Now supports installing a pre-release version of DigiByte Core with the ```--dgpre``` flag. Downgrade back to the release version with ```--dgbnopre```
- New: Add ```--help``` flag to DigiNode Setup script which describes all the available optional launch flags
- Fix: Improve checks for a failed install of DigiByte Core due to it using a non-standard folder structure. It will now restore the existing version from local backup and restart it.
- Change: Official URL is now diginode.tools. Bash script now uses setup.diginode.tools
- Change: Update Status Monitor to be able to detect a new prerelease/release version of DigiByte Core depending on which is in use
- Change: When quitting Status Monitor, the currently viewed DigiFact remains on the screen.

DigiNode Tools v0.7.4 - 2023-02-26
- More documentation tweaks
- Fix: Fixes to ```--locatedgb``` feature
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
- New: When using Unattended mode, you can now use the ```--skipcustommsg``` to skip the option to customize diginode.settings at first run.
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
- Fix: ```--skiposcheck``` flag now works as expected
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