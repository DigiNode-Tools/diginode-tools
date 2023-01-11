# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not yet connected to your Raspberry Pi in the Terminal using SSH, please complete STEP 5 first. Click [here](/docs/rpi_setup_step5_ssh_in_win.md) if you are on Windows, and [here](/docs/rpi_setup_step5_ssh_in_mac.md) for Mac.

## STEP 6 - Run DigiNode Setup

To run the DigiNode Setup script, in the terminal type the command: ```curl -sSL diginode-setup.digibyte.help | bash``` and press return.

![Run DigiNode Setup](/images/macos_setup_6_1a.png)

DigiNode Setup will start and perform some system checks, before taking you step-by-step with through the setup process.

![Run DigiNode Setup](/images/macos_setup_6_1b.png)

When prompted to customize your install, choose 'Continue' to stick with the defaults.

![Customize DigiNode Setup](/images/macos_setup_6_1c.png)

Once you reach the main menu, choose to install a 'Full DigiNode' and press return. DigiNode Setup will then start to download and configure the required software.

![Full Install in DigiNode Setup](/images/macos_setup_6_1d.png)

When asked whether to use uPnP for portforwarding, choose 'Setup Manually'. Before doing so, make a note of the port numbers.

In Step 7, you will learn how to forward these ports on your router.

![Port Forwarding in DigiNode Setup](/images/macos_setup_6_1e.png)

When prompted to install the custom MOTD, choose Yes.

![Install MOTD in DigiNode Setup](/images/macos_setup_6_1f.png)

When prompted to install the IPFS server profile, choose No.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1g.png)

Installation will continue. It will likely take a few minutes to complete. Go grab a coffee.

Note: At several points during the installation, it may look like it has frozen. Just be patient. You should eventually see the message telling you it has been installed.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1h.png)

Next restart the Raspberry Pi, by entering: ```sudo reboot``` and press return.

Wait a minute or two for the device to restart, and then reconnect over SSH again, using the same method from Step 5. e.g. ```ssh digbyte@diginode.local```

It will prompt you for your password again. When it reconnects, you should then see the DigiNode MOTD, reminding you of the commands to manage your DigiNode.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1i.png)

To check on the status of you DigiNode, launch the Status Monitor by typing ```diginode``` and pressing return.

![IPFS Server Profile in DigiNode Setup](/images/macos_setup_6_1j.png)

The final step is to setup port forwarding for the DigiNode. Press Q to quit the status monitor.

Tip: Whenever you want to disconnect from the Raspberry Pi, type ```exit``` and press return.

# NEXT: STEP 7 - Enable Port Forwarding (Instructions Coming Soon)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).