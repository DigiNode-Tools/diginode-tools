# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

Note: If you have not already connected the SSD to your Raspberry Pi and powered it on, then go [here](/docs/rpi_setup_step4_boot_pi.md) to complete STEP 4.

## STEP 5 - Connect to the Pi over SSH from macOS

You may be able to discover the IP address of the Raspberry Pi by logging into the web interface of your router and looking for it in the list of connected devices. If you already know the IP address to the Raspberry Pi, skip to step 5.5 below. Alternatively, you can use an IP address scanner, which is the method we will be using here. We will be installing the free open-source software called 'Angry IP Scanner'. If you already have this installed, open it now, and skip to step 5.4 below. 

### Step 5.3 - Install Angry IP Scanner

There are a few extra steps required to install it since the software is unsigned.

Open Safari, and visit [https://angryip.org/](https://angryip.org/) and click the 'Free Download' button.

![Download Angry IP Scanner](/images/macos_setup_5_3a.png)

Left-click on the download link for 'Mac Intel' or 'Mac ARM (M1/M2) depending on the type of Mac you are using.

![Download Angry IP Scanner](/images/macos_setup_5_3b.png)

If asked to allow downloads, click 'Allow':

![Download Angry IP Scanner](/images/macos_setup_5_3c.png)

Click on the 'Downloads' icon in the top-right corner of the Safari window, and then click on the magnifying glass icon next to the 'Angry IP Scanner' download to open the Downloads folder.

![Download Angry IP Scanner](/images/macos_setup_5_3d.png)

To install Angry IP Scanner, drag-and-drop it on to the Applications folder.

![Install Angry IP Scanner](/images/macos_setup_5_3e.gif)

Launch 'Angry IP Scanner'. (You can do this by pressing '⌘ + Space' to open Spotlight search, then type 'angry ip', clicking on the app, and pressing return.)

![Launch Angry IP Scanner](/images/macos_setup_5_3f.png)

You may see the message below saying that it cannont be opened. This is because the app is unsigned. If so, click 'Cancel'.

![Cannot Open Angry IP Scanner](/images/macos_setup_5_3g.png)

To give it permission to open, open 'System Settings' (Click the cog icon in the Dock.)

![Open System Settings](/images/macos_setup_5_3h.png)

In System Settings, click on 'Privacy & Security' and then click 'Open Anyway' next to the message saying it was blocked from use.

(Note: If you are running a version of macOS earlier than Ventura, you will have the old 'System Preferences' layout.)

![Open System Settings](/images/macos_setup_5_3i.png)

If prompted, enter your system password. (The password you enter when you sit down at your computer.) 

![Enter System Password](/images/macos_setup_5_3j.png)

At the message warning that the developer cannot be verified, click 'Open'.

![Cannot Verify Developer dialog](/images/macos_setup_5_3k.png)

'Angry IP Scanner' will open.

### Step 5.4 - Discover the IP address of the Raspberry Pi

Close the 'Getting Started' dialog in 'Angry IP Scanner' if it is visible.

![Close Getting Started in Angry IP Scanner](/images/macos_setup_5_4a.png)

Click the 'Start' to scan the IP addresses on your local network.

![Start Scan in Angry IP Scanner](/images/macos_setup_5_4b.png)

When the Scanning Completed dialog appears, click 'Close'.

![Scan Completed in Angry IP Scanner](/images/macos_setup_5_4c.png)

Look through the results, and locate the DigiNode hostname, and note its IP address.

![Scan Completed in Angry IP Scanner](/images/macos_setup_5_4d.png)

### Step 5.5 - Connect to the Raspberry Pi using SSH

Return to iTerm 2, and at the command prompt, enter the ssh command with the IP address from the previous step e.g. ```ssh digibyte@192.168.1.22```.

When connecting for the first time, it will then ask you if you want to continue. Type the word 'yes' at the prompt and press return.

![SSH to DigiNode](/images/macos_setup_5_5a.png)

At the next prompt, enter the password you created in STEP 3 and press return.

![SSH to DigiNode](/images/macos_setup_5_5b.png)

You are now connected to your Pi. You should see the 'digibyte@diginode' prompt. (or 'digibyte@diginode-testnet')

![SSH to DigiNode](/images/macos_setup_5_5c.png)


# NEXT: [STEP 6 - Run the DigiNode Setup script](/docs/rpi_setup_step6_run_diginode_setup.md)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).