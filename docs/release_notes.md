## DigiNode Tools Release Notes

DigiNode Tools - Unreleased
- New: **Automatic system updates** - DigiNode Setup can now install operating system updates for you automatically, once a day in the background (Debian, Ubuntu and Raspberry Pi OS). You are asked once: security and stability updates (recommended), all updates, or off. You can change this at any time from the new System option in the DigiNode Setup main menu. For an unattended install, set UI_SYSTEM_AUTO_UPDATES and UI_SYSTEM_AUTO_REBOOT in diginode.settings.
  ![The new Automatic System Updates menu in DigiNode Setup, with the choice of security and stability updates (recommended), all updates, or off](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/auto-updates/menu.png)
- New: **Automatic restarts, only when needed** - Your DigiNode can now restart itself automatically when an update needs a restart to finish, such as a new Linux kernel. It only restarts when needed, at 04:00 (you can change the time from the System menu), and never while it is busy - for example while DigiNode Setup is running or software is being installed. If it is busy, it tries again every 30 minutes for the next two hours, and otherwise the next night. Your DigiByte node is shut down safely and starts again automatically.
  ![The Automatic Restarts question in DigiNode Setup, explaining that the DigiNode restarts itself at 04:00 only when an update needs it, and never while it is busy](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/auto-updates/restart-question.png)
- New: **Restart reminders** - If your DigiNode needs a restart to finish installing system updates, you are now told when DigiNode Setup finishes, when you close DigiNode Dashboard, and when you log in (if you use the DigiNode MOTD). It also tells you if an automatic restart was skipped, and why.
  ![The DigiNode login message saying the DigiNode needs to restart to finish installing system updates, and that it will restart automatically at 04:00](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/auto-updates/restart-reminder.png)
- Improvement: **Commands work straight away** - The 'diginode' and 'diginode-setup' commands, and DigiByte Core's commands such as 'digibyte-cli', now work straight away after a new install - you no longer need to log out or restart first. They are now installed as commands in /usr/local/bin, instead of aliases in your .bashrc file, so they also work with sudo and in scripts, and they stop working straight away when you uninstall. Existing DigiNodes are switched over automatically the next time you run DigiNode Setup.
- Improvement: **No restart needed after hostname, swap or reset changes** - DigiNode Setup no longer tells you to restart after changing your hostname, changing your swap file or doing a reset, as these now take effect straight away. If your hostname changes, just reconnect using the new name.
- Improvement: **No restart needed after an uninstall** - After an uninstall, DigiNode Setup no longer tells you to restart your system, which wasn't needed. If the 'diginode' commands were removed, it now tells you to log out and back in instead, since the current terminal still remembers them.
- Fix: **Correct command for installing system updates** - The reminder to install system updates now tells you to run 'sudo apt-get update && sudo apt-get upgrade'. Running only 'sudo apt-get upgrade' could fail with "404 Not Found" errors if the list of available updates was out of date.

DigiNode Tools v26.10.04 - 2026-10-11
- New: For development and testing, the --dgntbranch flag installs a feature branch of DigiNode Tools from GitHub (e.g. diginode-setup --dgntbranch=feature/plugins). The branch is checked before anything is changed, so a mistyped or missing branch leaves your current DigiNode Tools in place. Like --dgntdev, running DigiNode Setup without the flag returns you to the latest release.
- Improvement: DigiNode Dashboard now checks for new versions of DigiNode Tools once an hour (previously once a day), so fixes reach you sooner, e.g. while you watch your node sync.
- Improvement: DigiNode Dashboard no longer checks for Kubo (IPFS) updates when Kubo isn't installed. This cuts an unneeded daily request to GitHub, which limits how often each internet connection can check for updates.

DigiNode Tools v26.10.03 - 2026-10-11
- Fix: DigiNode Setup could install the main branch of DigiNode Tools (used for final testing) instead of the latest release. This happened when GitHub limited how often your DigiNode could check for updates. DigiNode Setup now finds the latest release in a way that isn't limited, and if it still can't find it, it keeps your current version rather than installing anything else.

DigiNode Tools v26.10.02 - 2026-10-11
- New: When you quit DigiNode Dashboard and a DigiByte Core update is available, you can now choose "Don't ask me again". DigiNode Dashboard will then stop asking you to upgrade from the version of DigiByte Core you have installed, until you next upgrade or downgrade it. It still shows that an update is available, and you can upgrade at any time by running 'diginode-setup' and choosing Update. Updates to DigiNode Tools are still offered.
- Improvement: DigiNode Setup no longer waits for DigiByte Core to finish starting up before checking for updates, which could take 10 minutes or more. It now reads the installed version from the DigiByte Core install folder, which also gives the exact version of pre-releases.
- Fix: DigiByte Core is now given up to 10 minutes to shut down safely (previously 60 seconds). A node that is busy syncing, especially on a Raspberry Pi, could take longer than that to save its database, and was then force-stopped, which risks corrupting the blockchain data. Existing DigiNodes are updated automatically.
- Fix: DigiNode Dashboard no longer sometimes shows the previous version of DigiNode Tools when it starts, e.g. straight after an upgrade.
- Fix: DigiNode Dashboard no longer briefly shows a "du: cannot access" error at the bottom of the screen, about once a minute, while a DigiByte node is syncing.

DigiNode Tools v26.10.01 - 2026-10-10
- New: You can now install any version of DigiByte Core that has been verified for your DigiNode, going back to v7.17.2. Choose Version from the DigiNode Setup main menu to upgrade or downgrade. During a new install, you can choose to install the latest version (recommended) or an earlier one. Older pre-releases are always listed; a pre-release that is newer than the latest release is only listed if you use the --dgbpre flag. You are warned before installing an older version, and before downgrading to an older major version, which may require the blockchain to be resynced. You then confirm the version you chose, or go back and choose a different one.
- New: Install a specific version of DigiByte Core from the command line with the --dgbver flag (e.g. --dgbver=8.26.2). For an unattended install, set UI_DGB_VERSION in diginode.settings.
- New: DigiByte Core v9 has a brand new testnet, which is a separate blockchain from the old one used by v8 and earlier. When you upgrade (or downgrade) between them, DigiNode Setup now offers to delete the blockchain data for the testnet you are no longer using, to free up disk space. Your testnet wallets are always kept. Note: Wallets from one testnet cannot be opened by the other, and testnet DGB does not carry over to the new testnet.
- New: Delete blockchain data from the new Blockchain option in the DigiNode Setup main menu. Choose which chains to delete (mainnet, testnet, or the old v8 testnet), for example to resync a node that has stopped syncing or has corrupted data, or to free up disk space. Any node using the data is stopped while it is deleted and then restarted, so it resyncs from scratch. If the node wasn't running, you are asked whether to start it. Your wallets are never deleted.
- New: At the end of DigiNode Setup, any DigiByte node that should be running but isn't is started, and checked a few seconds later to make sure it is still running. If it fails to start, you are shown why from its log file. Nodes you stopped yourself with 'diginode --dgbstop' or 'diginode --dgb2stop' are left stopped.
- New: Press N in DigiNode Dashboard to hide (or show) your IP and onion addresses, e.g. before sharing a screenshot.
- Improvement: DigiNode Tools now uses date-based version numbers: the year, the month, and then the release number for that month. For example, v26.10.01 is the first release of October 2026. This makes it easy to see how up to date your DigiNode Tools are.
- Improvement: If you use the --dgbpre flag and there is no pre-release available, DigiNode Setup now offers to upgrade you to the latest release instead, if you don't already have it.
- Improvement: DigiNode Setup now downloads DigiByte Core using the exact download link and file name recorded when each release was verified, and no longer has to guess them. This fixes installing releases with unusual file or folder names, such as v8.22.0-final and v8.22.0-rc5, which could not be installed before.
- Improvement: DigiNode Setup no longer installs software it doesn't use: gcc, make, gnupg, tmux, iputils-ping, cron and apt-transport-https. (Already installed packages are not removed.)
- Improvement: The donation message now includes a link to sponsor DigiNode Tools on GitHub: https://github.com/sponsors/DigiNode-Tools - and thanks the Featured Sponsors of DigiNode Tools.
- Improvement: The out of date DigiAsset message in DigiNode Dashboard now explains how to help bring DigiAsset Core support to DigiNode Tools, by sponsoring it: https://diginode.tools/sponsors/
- Fix: Support for the new DigiByte Core v9 testnet, which stores its data in a different folder (~/.digibyte/testnet26) and uses different default ports (12033, and 14026 for RPC). DigiNode Dashboard now shows the correct testnet disk usage, ports and log file (diginode --dgb2log), and the mainnet disk usage no longer includes the testnet data. Deleting the testnet blockchain (e.g. when uninstalling) now removes the data for both the old and new testnet.
- Fix: Upgrading DigiByte Core while a node was still starting up left that node running the old version, and it was not restarted afterwards. It is now stopped, upgraded and restarted.
- Fix: Deleting the blockchain (e.g. when uninstalling) no longer deletes settings.json, which DigiByte Core uses to remember which wallets to load at startup.
- Fix: 'diginode --dgbrestart' and 'diginode --dgb2restart' now work for a node that crashed several times in a row. Previously they appeared to work, but the node was not started.
- Fix: Broken links to the static IP and port forwarding guide, and to the Argon One fan software.
- Fix: Security: Your digibyte.conf file, which contains your RPC password, can now only be read by your DigiNode user account. Previously, DigiNode Setup could leave it readable by every user on the system. This is fixed automatically the next time you run DigiNode Setup.
- Fix: DigiNode Dashboard no longer appears to freeze when a DigiByte node is too busy to respond, e.g. while it is syncing the blockchain. While it starts up, a spinner now shows when it is waiting for a node to respond. Once running, it shows that the node is busy and carries on as soon as the node responds again. Previously it could wait up to 15 minutes with no indication of what was happening.
- Fix: DigiNode Dashboard no longer shows an out of date sync percentage when a node has only just started syncing.
- Fix: Removed a "Permission denied" message shown when installing a DigiByte Core pre-release.
- Fix: DigiNode Setup no longer asks you to agree to the disclaimer again every time DigiNode Tools is upgraded.

DigiNode Tools v0.11.4 - 2026-10-09
- New: The SHA256 hashes used to verify each DigiByte Core download are now published automatically at https://github.com/DigiNode-Tools/digibyte-hashes instead of on the diginode.tools website. Each new DigiByte Core release is checked every day, and its hash is only published once it matches the hash GitHub recorded when the file was uploaded, and the SHA256SUMS file included with the release (where available).
- Improvement: New DigiByte Core releases are now rolled out to DigiNodes gradually, between 3 and 15 days after they are released. This gives time for any problems with a new release to be discovered before everyone upgrades.
- Fix: DigiNode Dashboard no longer tells you that a DigiByte Core update is available until it has been verified for your DigiNode. Previously it could show an update straight away that DigiNode Setup would then refuse to install.
- Fix: If the newest DigiByte Core release has not reached your DigiNode yet, DigiNode Setup will now upgrade you to the newest version that has. Previously, the upgrade was skipped altogether.
- Fix: DigiNode Dashboard now checks for a newer DigiByte Core release every day, even when an update is already waiting to be installed.
- Fix: Upgrading between DigiByte Core pre-releases now works with the new version format (e.g. v9.26.6rc1 to v9.26.6rc2, and v9.26.6rc2 to v9.26.6). Previously, these upgrades were not offered.
- Fix: DigiByte Core releases that have no download for your type of device (e.g. v8.26.0 and v8.26.1 on a Raspberry Pi) are no longer offered.
- Fix: Reset Mode now shows the correct DigiByte Core version when running a pre-release.

DigiNode Tools v0.11.3 - 2025-04-30
- New: Add a few more DigiNode tips.
- Fix: Argon fan software should now install correctly.
- Fix: Listening port should no longer display as "null" when the digibyte node itself is not self-reporting its local addresses and port. (It now reverts to getting this from digibyte.conf)

DigiNode Tools v0.11.2 - 2025-04-22
- Improvement: The Port Tester now gets re-enabled automatically 24 hours after the test was last successfully passed.
- Fix: Hopefully the startup error that is occasionally been seen is now fixed.

DigiNode Tools v0.11.1 - 2025-04-20
- Improvement: Default auto quit duration for the DigiNode Dashboard has been changed to 24 hours (1440 minutes).
- Improvement: Mempool bytes are hidden on narrower terminal windows to make the display cleaner.
- Fix: When running a Dual Node, the Testnet listening port now displays correctly in the Dashboard while the node is starting up. (It was blank before)
- Fix: Right border for Connections row in dashboard now fits better.

DigiNode Tools v0.11.0 - 2025-04-19
- New: DigiNode Dashboard now has a brand new port tester built for DigiNode Tools. It can test nodes at IPv4, IPv6 and onion addresses. The port tester is also available for anyone to use at: https://diginode.tools/digibyte-port-tester/
- New: DigiNode Dashboard now optionally displays the mempool data for each node. By default, Mempool data is displayed whenever transactions enter the mempool and is hidden if there are no transactions seen for 30 seconds. This way mempool data is shown only when there is mempool data to show. You can enable/disable displaying the mempool data by editing the variables SM_DISPLAY_MAINNET_MEMPOOL and SM_DISPLAY_TESTNET_MEMPOOL in diginode.settings. (Enter ```diginode --settings```). SM_MEMPOOL_DISPLAY_TIMEOUT can be used to set the timeout duration.
- New: DigiNode Dashboard now displays the incoming and outgoing connections for your DigiByte node.
- Improvement: peers.dat is now deleted each time you switch between running a Tor node and a clearnet node. This ensures the node starts with a fresh list of peers to connect to.
- Improvement: Add message to Dashboard about DigiAsset Core support. Adding support for DigiAsset Core is not possible at this time due to a bug in DigiByte Core v8.22.x.
- Improvement: DigiNode Dashboard autoquit timer is now much more accurate.
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
- New: Uninstaller now prompts to uninstall Regtest and Signet blockchain data if present
- Fix: When running a Dual Node, the secondary Testnet node now gets shutdown correctly before performing an uninstall
- Fix: Blockchain data is now uninstalled fully, when switching between running mainnet and testnet nodes (and vice versa)

DigiNode Tools v0.10.8 - 2025-02-11
- Improvement: Update the DigiFacts web service URL which has changed to: https://digifacts.diginode.tools. The DigiFacts Github repo has moved to: https://github.com/DigiNode-Tools/DigiByte-DigiFacts-JSON

DigiNode Tools v0.10.7 - 2025-02-08
- Fix: ```diginode --dgbpeers``` and ```diginode --dgb2peers``` should now display the onion peers correctly.

DigiNode Tools v0.10.6 - 2025-02-07
- New: Rewritten Raspberry Pi hardware checker. It should now automatically identify all Raspberry Pi hardware - including all recent models of the Raspberry Pi 5 and any future models yet to be released.
- New: Can now identify when a DigiNode is booting off a PCIe NVME SSD on the Raspberry Pi 5.
- New: DigiNode has now been fully tested on the Raspberry Pi 5 8Gb with a PCIe NVME SSD. Everything works as intended. All Raspberry Pi 5 models with 4Gb RAM should be supported. 8Gb RAM or more is strongly recommended. Please post a message in the Telegram group if you encounter any issues: https://t.me/DigiNodeTools

DigiNode Tools v0.10.5 - 2025-02-06
- New: DigiNode Setup now displays the version number at launch. This should make troubleshooting easier by making it much easier to tell which version you are currently running.
- New: The --listwallets flag displays the currently installed wallets. This is part of a planned suite of wallets tools. (May not work yet.)
- Improvement: Replace X support links for Bluesky as the account is no longer in use

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
- Improvement: ```--dgbpeers``` and ```--dgb2peers``` now also displays the onion peers, if available.
- Improvement: The flag ```--dgbcfg``` is now ```--dgbconf```. The flag ```--dgntset``` is now ```--settings```. This should hopefully make them easier to remember.
- Fix: Bug that prevents the mainnet and testnet node from starting up if the user installs a Dual Node on a clean system.
- Fix: Error in Dashboard when running only a Testnet node
- Fix: Error loading CPU usage at Dashboard startup

DigiNode Tools v0.9.13 - 2024-05-25
- Improvement: Remove DigiAsset Node software. This is temporary. The legacy DigiAsset Node software has not been functioning correctly for some time and has therefore been retired. The release will automatically purge it from your DigiNode. Support for the new DigiAsset Core, which is a complete rewrite of the DigiAsset software, will be added in an upcoming release.
- Fix: Better detection in the Dashboard for when the DigiNode is offline.

DigiNode Tools v0.9.12 - 2024-04-10
- New: Updated Raspberry Pi detection to identify newer Pi 4, Pi CM4, Pi 400 and Pi 5 models.
- New: DigiNode Tools must be running the latest version to install the other updates. This helps to avoid any install changes between versions.
- Fix: Hide displayed download progress when checking for DigiByte Core update at Dashboard launch

DigiNode Tools v0.9.11 - 2024-04-02
- New: Add support for DigiByte Core v8.22.0-rc4

DigiNode Tools v0.9.10 - 2024-03-29
- Improvement: Uninstalling blockchain data now deletes everything except the wallet (previously it kept the banlist, mempool, peers etc.)
- Improvement: DigiNode Tools Github repo has moved to the new DigiNode Tools org on Github. All links have been updated to reflect this.
- Fix: Testnet peers now sort alphabetically as well when using ```--dgb2peers```.

DigiNode Tools v0.9.9 - 2024-02-04
- Improvement: Remove testnet / dual node warning message.
- Fix: Sync progress in DigiNode Dashboard is now correctly calculated.
- Fix: Error detecting avahi-daemon in Dashboard.
- Fix: No longer prompts to overwrite DigiFacts JSON.

DigiNode Tools v0.9.8 - 2024-02-03
- Fix: DigiNode Tools now correctly installs DigiByte Core 8.22.0-rc3 that has just been released.

DigiNode Tools v0.9.7 - 2024-02-03
- New: When installing/upgrading DigiByte Core the script now looks for a sha256 hash on the DigiNode Tools website and only allows the install/upgrade to proceed if it is available. Once downloaded, the new binary is checked against the hash to make sure that it has not been tampered with. This change significantly improves DigiNode security providing protection in the event that the DigiByte Core repo is compromised. In an emergency you can bypass these checks using the ```--skiphash``` flag though this is not recommended.
- New: Users must now agree to the software disclaimer before using DigiNode Tools. Continued use of DigiNode Tools constitutes you agree to the terms in the disclaimer. You will be asked to agree each time there is a new release.
- Improvement: ```--dgbpeers``` and ```--dgb2peers``` now list peers alphabetically.
- Improvement: In DigiNode Dashboard, "System Time" and "Online Since" are now displayed in UTC regardless of the server location or the user's local time. This makes it easier to compare the current state of differnet nodes regarldess of where they are located.
- Fix: In DigiNode Dashboard, if the external and internal IP addresses are both the same (i.e. we are on a server with a public IP), then it now only shows the external IP.
- Fix: In DigiNode Dashboard, an error no longer displays if there is no IP6 address.

DigiNode Tools v0.9.6 - 2024-01-19
- New: The DigiNode Tools website is finally live: [https://diginode.tools](https://diginode.tools)
- Improvement: Most of the project documentation has been moved from Github to the DigiNode Tools website.
- Fix: Individual CPU usage in DigiNode Dashboard is correctly aligned regardless of percentage.

DigiNode Tools v0.9.5 - 2024-01-14
- New: Use the ```diginode --dgb2log``` flag to view the DigiByte Node testnet log while running a Dual Node.
- Improvement: 'Upgrade Available' dialog now shows exactly what will be upgraded
- Fix: Downgrading from a DigiByte pre-release back to the latest release now works as expected.
- Fix: Passwordbox inputs now work as expected

DigiNode Tools v0.9.4 - 2024-01-12
- New: DigiFacts are now updated once per hour from the DigiByte DigiFacts - JSON Web Service. You can find it [here](https://digifacts.digibyte.help/?help). Developers are encouraged to use the DigiFacts web service in their DigiByte projects. You can help contribute new DigiFacts,improve existing ones, translate them into additional languages, or donate to the translation fund. Learn more [here](https://github.com/saltedlolly/DigiByte-DigiFacts-JSON).
- New: Use the ```diginode --porttest``` flag to manually re-enable the DigiByte Node and DigiAsset Node port tests, if needed.
- Improvement: Remove support for running a DigiAsset Node ONLY. [DigiAsset Core](https://github.com/DigiAsset-Core/DigiAsset_Core), which will soon replace the current DigiAsset Node software, requires a DigiByte Node to function. It will no longer be possible to run a DigiAsset Node without a DigiByte Node so this option has been removed. You can learn more about DigiAsset Core [here](https://digiassetcore.digiassetx.com/).
- Improvement: If there are multiple updates available, DigiNode Setup now lets you install them individually.
- Improvement: CPU usage in DigiNode Dashboard is now displayed as a whole number.
- Improvement: Remove digifact78 from digifacts.json as this describes DigiNode Tools itself.
- Improvement: Removed Ubuntu workaround as this is no longer required
- Improvement: Rename "Kubo IPFS" to "IPFS Kubo" to match official IPFS naming
- Fix: Switch from using whiptail menus to dialog menus. This is to get around the Debian bug that is causing the menus to be unresponsive at first launch - key presses do not work and it is impossible to proceed. This bug affected whiptail menus - dialog is not affected - and is triggered when piping through bash. By switching to dialog we bypass the issue, and no longer need the Ubuntu workaround.
- Fix: Web UI URL in DigiNode Dashboard now gets split across two lines when required, if there are two URLs.

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
- Improvement: Status Monitor 15 second timer now runs every 10 seconds.
- Improvement: Improve formatting of wallet balance in status monitor.
- Improvement: IPFS now uses the lowerpower profile on a Raspberry Pi
- Fix: Improve ability to recognize system RAM on an unknown Raspberry Pi model.
- Fix: Node.js installer now uses the new Nodesource repositories.
- Fix: Repair misalligned column in Status Monitor when swap size is double figures.
- Fix: IPFS cat command now attempts to download the new readme file to test your install. The old one was no longer available, so would always fail.
- Fix: DigiNode Setup now correctly runs Rasperry Pi checks unless we are in DigiAsset Node ONLY Mode.

DigiNode Tools v0.8.6 - 2023-08-27
- Improvement: DigiAsset Node node now displays block height with commas so it is easy to read
- Fix: UPnP menu now displays current DigiByte port correctly

DigiNode Tools v0.8.5 - 2023-08-26
- Fix: Bug with ```--skippkgupdate```

DigiNode Tools v0.8.4 - 2023-08-21
- Fix: Rework the process of upgrading from running a DigiAsset Node ONLY to a FULL DigiNode. Now works correctly when using the ```--dgbpre``` flag.

DigiNode Tools v0.8.3 - 2023-08-21
- Improvement: More documentation improvements
- Improvement: Add ```--help``` tip to MOTD
- Fix: Minor bug when installing MOTD
- Fix: Status Monitor now displays "Block Height" from the DigiAsset Node console. I previously did not include this simply to save space, but I have recently discovered that this sometimes displays important error messages. It has also a revealed a bug with the DigiAssets Node which DigiAssetX is working to fix.

DigiNode Tools v0.8.2 - 2023-08-18
- Improvement: Switch Twitter social links to use @dignodetools instead of @digibytehelp. Also, add additional links to Bluesky account and Telegram group.
- Improvement: Now displays web UI IP address alongside hostname. For various reasons, sometimes the hostname does not work when used in the URL, so best to have a backup option.
- Improvement: Lots of documentation improvements.
- Fix: Several minor bug fixes

DigiNode Tools v0.8.1 - 2023-08-15
- Improvement: Improved one-page setup instructions for Raspberry Pi to make it clearer
- Fix: Improve handling of a failed Kubo download - will now completely skip DigiAsset Node install/upgrade in this situation
- Fix: Added workaround for Kubo release glitch - automatically downloads v0.22.0 when v0.21.1 is detected

DigiNode Tools v0.8.0 - 2023-08-14
- New: Now supports installing a pre-release version of DigiByte Core with the ```--dgpre``` flag. Downgrade back to the release version with ```--dgbnopre```
- New: Add ```--help``` flag to DigiNode Setup script which describes all the available optional launch flags
- Improvement: Official URL is now diginode.tools. Bash script now uses setup.diginode.tools
- Improvement: Update Status Monitor to be able to detect a new prerelease/release version of DigiByte Core depending on which is in use
- Improvement: When quitting Status Monitor, the currently viewed DigiFact remains on the screen.
- Fix: Improve checks for a failed install of DigiByte Core due to it using a non-standard folder structure. It will now restore the existing version from local backup and restart it.

DigiNode Tools v0.7.4 - 2023-02-26
- New: Add checksum comparison when backing up or restoring wallet.dat to/from a USB stick. This verifies that the wallet file has been copied correctly, during a backup or restore.
- Improvement: More documentation tweaks
- Fix: Fixes to ```--locatedgb``` feature

DigiNode Tools v0.7.3 - 2023-01-15
- Fix: Display testnet/mainnet selection menu correctly
- Fix: Documentation tweaks and typos
- Fix: Argon One fan installer script, under the 'Extras' menu, should now install correctly

DigiNode Tools v0.7.2 - 2023-01-14
- New: Added step-by-step instructions for setting up a DigiNode on a Raspberry Pi
- Improvement: If system RAM exceeds 12Gb, dbcache is now set to 2Gb (aimed at machines with 16Gb RAM)
- Fix: Status Monitor now displays correct sync progress when running testnet
- Fix: Status Monitor now starts correctly when digibyted is not running
- Fix: Add workaround for installing DigiNode Tools on Ubuntu

DigiNode Tools v0.7.1 - 2022-12-28
- New: Add a custom DigiNode MOTD that displays when you login to the machine via the terminal. It includes the DigiNode logo and brief usage instructions to remind the user of the commands to launch 'DigiNode Setup' and 'DigiNode Status Monitor'.
- New: During the first install, the user is asked whther or not they want to install the DigiNode MOTD.
- New: The existing system MOTD is backed up to ~/.motdbackup and restored from there if you later uninstall the DigiNode MOTD
- New: The DigiNode MOTD can also be installed/removed via the main menu.

DigiNode Tools v0.7.0 - 2022-12-25
- New: Add new menu driven options to choose between running a DigiByte mainnet and testnet node
- New: DigiByte network can also be specified via diginode.settings when performing an unattended install
- New: Status Monitor now displays when it is monitoring a DigiByte testnet node
- New: DigiNode Setup menu now lets you easilly switch between running a DigiByte testnet and mainnet nodes. It will also prompt you to delete the blockchain data for the unused chain.
- New: When running a testnet node, it will now offer to change the hostname to diginode-testnet. This is to make it easy to run two DigiNodes on the same network - one on mainnet and the other on testnet.
- Improvement: Switching between running mainnet and testnet, also changes the rpcport if it using the default one
- Improvement: If running testnet, IPFS with will now automatically switch to using port 4004. (By default it uses 4001.) This is to prevent two DigiNodes - one mainent and one testnet - running on the same network, from conflicting with each other. (Note: If the IPFS config uses a port that differs from 4001 or 4004 the port will remain unchanged.)

DigiNode Tools v0.6.7 - 2022-12-15
- New: Add testnet flag to digibyte.conf
- Improvement: Updated Recomended Hardware documentation

DigiNode Tools v0.6.6 - 2022-12-12
- Improvement: Improvements to this documentation.
- Fix: Fix bug when running unattended update from DigiNode Status Monitor

DigiNode Tools v0.6.5 - 2022-08-20
- Fix: Fix creating a swap file in Debian 11 

DigiNode Tools v0.6.4 - 2022-08-12  
- Improvement: Status Monitor - Bring back the ability to press Q to Quit, in case Ctrl-C doesn't work. 
- Fix: Lots of bug fixes and formatting issues

DigiNode Tools v0.6.3 - 2022-08-10
- New: DigiNode Setup now prompts the user to create a swap file if RAM + SWAP <12Gb. This is to ensure that DigiByte Nodes and DigiAsset Node can work smoothly on the same device. This solves a problem of DigiByte Core running out of memory on a 8Gb device that is also running a DigiAsset Node.
- Improvement: Automatic swap file creation is now supported on Debian as well as Ubuntu. The recommended total memory (swap + ram) has been increased from 8Gb to 16Gb. This means if you have a 8Gb device it will recomend creating an 8Gb swap file.
- Improvement: Status Monitor - Swap Usage now shows how much swap is free.

DigiNode Tools v0.6.2 - 2022-08-07
- Fix: Improve Status Monitor auto-quit instructions
- Fix: Hide key press codes when scrolling in status monitor
- Fix: Renable port test when DigiByte port changes

DigiNode Tools v0.6.1 - 2022-08-06
- Improvement: DigiNode Tools now requires DigiAsset Node v4. Until v4 is released, it will now install the development branch automatically. (DigiAsset Node v3 does not work correctly with Kubo IPFS, but this issue has been fixed in v4 development version.)
- Improvement: DigiByte port test is now automatically re-enabled if the port has changed since it last successfully passed the test.
- Improvement: Port tester can now handle using a non-standard listening port (i.e. not port 12024)
- Fix: Fix DigiByte port tester to not display an error  when the testing site is down or busy.

DigiNode Tools v0.6.0 - 2022-08-05
- New: Status Monitor - Add DigiByte port test developed by Renzo Diaz for the DigiByte Alliance. This makes it easy to quickly test if port 12024 is open. It queries an external API then tests if your port is open.
- New: DigiNode Setup - Added uPnP Menu which asks to enable/disable UPnP for DigiByte Core and IPFS during first install. In unattended mode its gets the values from diginode.settings. Once installed, you can enable/disable UPnP via the main menu.
- New: DigiNode Setup - The user is now asked if they want to enable the IPFS Server profile when first installed. The server profile disables IPFS local host discovery - ueful when running a DigiAsset Node on a server with a public IP address. In unattended mode its gets this value from diginode.settings. 
- New: DigiNode Setup - Add option to delete the ~/.jsipfs folder when uninstalling DigiAsset Node
- Improvement: Status Monitor - DigiByte 'starting up' messages are now in yellow to indicate a temporary issue
- Improvement: Status Monitor - Improve detection of when DigiNode internet connection is online/offline
- Improvement: Status Monitor - Improve startup messaging. It now displays each step that is being processed when running though the status loop for the first time. It shows that it is actually doing something, rather than having the user stare at a frozen screen.
- Improvement: Status Monitor - To ovoid putting extended strain on the server, the Status Monitor now quits automatically after 20 minutes. The duration is now set in minutes rather than seconds. A message is now displayed when it auto-quits.

DigiNode Tools v0.5.6 - 2022-08-01
- New: Status Monitor now quits automatically after one hour by default
- New: When using Unattended mode, you can now use the ```--skipcustommsg``` to skip the option to customize diginode.settings at first run.
- New: Status Monitor now includes if there is a payout address for the DigiAsset Node

DigiNode Tools v0.5.5 - 2022-07-31
- New: Status Monitor will now detect if the DigiAsset Node goes offline and when it comes back online again.
- New: Status Monitor IPFS status now shows in yellow when starting up etc.
- New: Kubo API URL gets added to main.json when Kubo is installed and removed when it is deleted. DigiAsset Node restarts when Kubo is removed to ensure it switches to using JS-IPFS.
- Improvement: Updated README
- Fix: The Status Monitor can now better detect if the DigiAsset Node is running.

DigiNode Tools v0.5.4 - 2022-07-30
- New: Add IPFS URL to main.json template so DigiAsset Node will use Kubo rather than js-IPFS
- New: Status Monitor now display IPFS status in red if the port is blocked
- New: Add new 'Extras' menu with an option to install the fan softwrare for the Argon ONE Case for the Raspberry Pi 4
- Fix: Improvements to the DigiAsset Node upgrade process - fix rare incidence when PM2 processes get duplicated
- Fix: DigiAsset Node blocked port issue seems to have been resolved

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
- Improvement: Wallet balance will now only display if the balance is greater than 0.
- Improvement: Backup reminder will only be displayed if the wallet balance is greater than 0.
- Improvement: Improve messaging when restoring a DigiByte wallet from backup
- Improvement: Hide cloud IP in closing messages if it is the same as the internal IP 

DigiNode Tools v0.4.4 - 2022-07-24
- New: Add option to display the wallet balance in the Status Monitor. You can choose not to display this by setting the SM_DISPLAY_BALANCE variable in diginode.settings
- New: Status Monitor now displays the disk usage percentage in red if it is 80% or over
- New: Add check to make sure the DigiByte Core download completes successfully.

DigiNode Tools v0.4.3 - 2022-07-23
- New: Add ```--skipupdatepkgcache``` flag for skipping package update check at startup (some VPS won't let you update)
- Improvement: Assorted fixes and improvements to make it easier to run DigiNode Tools on a VPS
- Fix: When performing a DigiAsset Node Only setup, it now checks for NodeJS

DigiNode Tools v0.4.2 - 2022-07-23
- New: Current block count in Status Monitor now has thousands seperated by commas
- Fix: Change mentions of 'go-ipfs' in Github download to 'kubo' - downloads have been renamed. Same with the install folder.
- Fix: If Kubo download fails (maybe the download URL has changed?), restart the existing version and exit. This ensures that a change in the download URL will not break existing installs.

DigiNode Tools v0.4.1 - 2022-07-17
- Fix: Improve DigiByte locate menu during Status Monitor startup

DigiNode Tools v0.4.0 - 2022-07-17
- Improvement: Rewrote closing messages to be clearer
- Fix: Uninstall now prompts to remove DigiByte Core and the DigiByte blockchain only if they are present
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
- Improvement: Add more screenshots to the README
- Improvement: Documentation updates
- Improvement: Update several DigiFacts

DigiNode Tools v0.3.4 - 2022-07-10
- New: Add reminder to install system updates if there are any
- Improvement: DigiNode dependencies are now installed before DigiNode Setup begins. Avahi-daemon is still installed just before the hostname change.

DigiNode Tools v0.3.3 - 2022-07-09
- Fix: Don't restart digibyted before wallet backup if it is already running
- Fix: Memory/swap values in Status Monitor should now display correctly

DigiNode Tools v0.3.2 - 2022-07-09
- Fix: Formatting for Disk Usage in Status Monitor
- Fix: Formatting for 'DigiAsset Node is not running' message in Status Monitor
- Fix: PM2 process detection now works correctly

DigiNode Tools v0.3.1 - 2022-07-09
- New: DigiNode Tools now work on x86_64 architecture so you can use it to setup a DigiNode on PC hardware. (Please help test!)
- Improvement: Rename Go-IPFS to Kubo (the name has been changed)
- Improvement: IPFS Updater utility is no longer used to install Kubo (formerly Go-IPFS). It is now installed by DigiNode Setup itself.
- Fix: Hide temperature in Status Monitor if it cannot be read from the system
- Fix: In Status Monitor, hide DEVICE row if the device is unknown
- Fix: Improve the scripts ability to detect if DigiAsset Node is installed and/or running.

DigiNode Tools v0.2.5 - 2022-07-07
- New: Improve documentation by adding equipment suggestions for building your own DigiNode
- Fix: ```--skiposcheck``` flag now works as expected

DigiNode Tools v0.2.4 - 2022-07-01 
- Fix: Installation now cancels if Go-IPFS fails to install. There is a recurring problem with the install files not downloading which may be a probelm with their servers. Typically, if you keep retrying it will eventually work.
- Fix: Hide swap status in status monitor if the swap is tiny (i.e. around 1 Mb)
- Fix: Correct error display if IPFS install fails

DigiNode Tools v0.2.3 - 2022-07-01
- Fix: Start IPFS daemon during an update if it installed but not currently running (perhaps due to a failed previous install)
- Fix: If you launch Backup/Restore from the menu, and then run Update, the script now performs as expected. Before it would loop back and continue backup/restore from where you had stopped halfway though.
- Fix: Formatting of update display in status monitor

DigiNode Tools v0.2.2 - 2022-06-29
- Fix: Fix DigiNode Tools update checker

DigiNode Tools v0.2.1 - 2022-06-29
- New: Add Restore feature - you can now restore your DigiByte wallet and/or DigiAsset Settings from a previously created USB backup.
- Improvement: You can now cancel inserting a USB stick by pressing a key
- Improvement: Status monitor now displays more detail while waiting for DigiByte daemon to finish starting up
- Fix: Change Status Monitor timers to use unix time to fix a bug where they don't get triggered correctly
- Version number has been bumped to reflect new features added
- Note: Due to changes in how the Status Monitor tracks time, you may need to delete your existing diginode.settings file before use

DigiNode Tools v0.0.9 - 2022-05-27
- Fix: Fixes for the DigiNode Tools version checker
- Pushed out several releases to test its ability to detect and install new versions.

DigiNode Tools v0.0.8 - 2022-05-26
- Fix: Another attempt to fix DigiNode Tools verion checks

DigiNode Tools v0.0.7 - 2022-05-26
- Fix: Another attempt to fix DigiNode Tools version checks

DigiNode Tools v0.0.6 - 2022-05-26
- Improvement: diginode.settings variables now get reset during an uninstall
- Improvement: Backup reminder is displayed until you have made one
- Fix: Reboot is hopefully no longer required after first install
- Fix: Lots of fixes and improvements to backup function

DigiNode Tools v0.0.5 - 2022-05-19
- New: Any changes made to the RPC credentials (user/password/port) in digibyte.conf are now automatically updated in the DigiAssets settings file (main.json) file when running an 'Update' from the DigiNode Setup menu.
- Improvement: USB Backup feature now backs up DigiAsset settings as well as DigiByte Wallet
- Fix: DigiAsset Settings are backed up locally when uninstalling, if desired. This fixes the update bug mentioned in v0.0.4
- Fix: Fixes to diginode.settings to better store variables
- Fix: Countless bug fixes and improvements

DigiNode Tools v0.0.4 - 2022-05-10
- New: Implemented backup feature for prelimanry testing
- Improvement: Install URL has changed to diginode-setup.digibyte.help
- Improvement: Renamed every mention of "DigiNode Installer to "DigiNode Setup"
- Fix: Fixed several bugs relating to the Status Monitor being able to check for software updates
- WARNING: There is currently a bug with the DigiAsset Node updater that will erase your configuration. I am currently working to fix this.  

DigiNode Tools v0.0.2 - 2021-11-14
- Test Release for the update mechanism

DigiNode Tools v0.0.1 - 2021-11-12
- First test release
