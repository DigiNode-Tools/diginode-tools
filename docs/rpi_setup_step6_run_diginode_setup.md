# DigiNode Setup Guide for the Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not yet connected to your Raspberry Pi in the Terminal using SSH, please complete STEP 5 first. Click [here](/docs/rpi_setup_step5_ssh_in_win.md) if you are on Windows, and [here](/docs/rpi_setup_step5_ssh_in_mac.md) for Mac.

## STEP 6 - Run the DigiNode Setup script on your Raspberry Pi

*Tip: Sometimes when using DigiNode Tools it displays website URLs - to open these in your browser, you can hold the Command '⌘' key (Mac) or the Ctrl key (Windows) and then clicking on them.*

To run the DigiNode Setup script, in the terminal type the command: ```curl -sSL diginode-setup.digibyte.help | bash``` and press return.

![Run DigiNode Setup](/images/macos_setup_6_1a.png)

DigiNode Setup will start and perform some system checks, before taking you step-by-step with through the setup process.

IMPORTANT: In DigiByte Core v7.17.3 there is a bug which means you cannot effectively run a testnet node on a Raspberry Pi. This will be fixed in v8.

![Run DigiNode Setup](/images/macos_setup_6_1b.png)

When prompted to customize your install, choose 'Continue' to stick with the defaults.

![Customize DigiNode Setup](/images/macos_setup_6_1c.png)

Once you reach the main menu, choose to install a 'Full DigiNode' and press return. DigiNode Setup will then start to download and configure the required software.

![Full Install in DigiNode Setup](/images/macos_setup_6_1d.png)

When asked whether to use uPnP for portforwarding, choose 'Setup Manually'. Take note of the port numbers.

In Step 7, you will learn how to forward these ports on your router.

![Port Forwarding in DigiNode Setup](/images/macos_setup_6_1e.png)

When prompted to install the custom MOTD, choose Yes.

![Install MOTD in DigiNode Setup](/images/macos_setup_6_1f.png)

When prompted to install the IPFS server profile, choose No.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1g.png)

Installation will continue. It will likely take a few minutes to complete. Go grab a coffee.

Note: At several points during the installation, it may look like it has frozen. Just be patient. You should eventually see the message telling you it has been installed.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1h.png)

Next restart the Raspberry Pi, by typing ```sudo reboot``` followed by return.

Wait a minute or two for the device to restart, and then reconnect over SSH again, using the same method from Step 5. e.g. ```ssh digbyte@diginode.local```

It will prompt you for your password again. When it reconnects, you should then see the DigiNode MOTD, reminding you of the commands to manage your DigiNode.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1i.png)

To check on the status of your DigiNode, launch the Status Monitor by typing ```diginode``` followed by return.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1j.png)

Press Q to quit the status monitor.

The final step is to setup port forwarding for the DigiNode.

### Some Useful Commands

If you are new to Linux, you may find these commands useful. You can type each one into the terminal and press return.

- ```exit``` - disconnect from the Raspberry Pi
- ```ls``` - view the contents of the current directory
- ```ls -all``` - view the contents of the current directory, including any hidden files or directories (Note: Hidden files or foldes start with a period.)
- ```cd <directory path>``` - Navigate into a directory. e.g. ```cd ~/.digibyte```
- ```cd ..``` - Navigate out of the current directory.
- ```cd ~``` - Return to the home folder.
- ```nano <file name>``` - Edit a file using nano. e.g. ```nano ~/.digibyte/diginode.settings```
- ```sudo``` - Prefix to other commands. It gives you elevated superuser permissions to execute that command. You will be prompted for your password.
- ```sudo reboot``` - Reboot the system. 
- ```sudo shutdown``` - Shutdown the system.
- ```sudo apt-get update``` - Check for system updates.
- ```sudo apt-get upgrade``` - Install system updates.
- ```sudo raspi-config``` - Launch the 'Raspberry Pi Software Configuration Tool' (use it to configure wifi, overclock the Pi etc.)
- ```sudo systemctl restart digibyted``` - Restart DigiByte full node.
- ```sudo systemctl restart ipfs``` - Restart IPFS.
- ```pm2 restart digiasset``` - Restart DigiAsset Node.

To learn more Linux commands, go [here](https://www.digitalocean.com/community/tutorials/linux-commands).

# NEXT: STEP 7 - [Give the Raspberry Pi a Static IP address and setup Port Forwarding](/docs/rpi_setup_step7_forward_ports.md)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).