# DigiNode Setup Guide for the Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not already connected the SSD to your Raspberry Pi and powered it on, then please go [here](/docs/rpi_setup_step4_boot_pi.md) and complete STEP 4.

## STEP 5 - Connect to the Raspberry Pi from your Mac

You will now connect to the Raspberry Pi from your main computer using SSH (Secure Shell). You will then be able to run the DigiNode Setup script.

(Note: The instructions on this page are for macOS. If you on Windows, click [here](/docs/rpi_setup_step5_ssh_in_win.md).)

### Step 5.1 - Download and install 'iTerm 2'

Rather than using the the built-in Terminal app to connect to your Raspberry Pi, it is recommended to use 'iTerm 2' which has better support for the text formatting used by DigiNode Tools. It's free.

Open Safari, and visit [https://iterm2.com/](https://iterm2.com/) and click the 'Download' button.

![Download iTerm 2](/images/macos_setup_5_1a.png)

If asked to allow downloads, click 'Allow':

![Download iTerm 2](/images/macos_setup_5_1b.png)

Click on the 'Downloads' icon in the top-right corner of the Safari window, and then click on the magnifying glass icon next to the 'iTerm' download to open the Downloads folder.

![Download iTerm 2](/images/macos_setup_5_1c.png)

To install iTerm 2, drag-and-drop it on to the Applications folder.

![Install iTerm 2](/images/macos_setup_5_1d.gif)

### Step 5.2 - Connect to the Raspberry Pi using SSH

Launch iTerm 2. (You can do this by pressing '⌘ + Space' to open Spotlight search, then type 'iterm' and press return.)

![Launch iTerm 2](/images/macos_setup_5_2a.png)

If you see the warning message, click 'Open'.

![Launch iTerm 2](/images/macos_setup_5_2b.png)

At the command prompt in iTerm 2, type ```ssh digibyte@diginode.local``` and press return to connect to the Raspberry Pi.

(If you set the hostname to 'diginode-testnet', use ```ssh digibyte@diginode-testnet.local```)

![SSH to DigiNode](/images/macos_setup_5_2c.png)

(NOTE: If it is unable to find your Raspberry Pi on your local network, it may get stuck on the screen above - press 'Ctrl + C' to cancel. In this event, you will need to connect using the IP address of the Pi instead. e.g. ```ssh digibyte@192.168.1.10```. If you don't already know the IP address, go [here](/docs/rpi_setup_step5_ssh_in_mac_find_ip.md) for instructions on how to find it.)

When connecting for the first time, it will then ask you if you want to continue. Type the word 'yes' at the prompt and press return.

![SSH to DigiNode](/images/macos_setup_5_2d.png)

At the next prompt, enter the password you created in STEP 3 and press return.

![SSH to DigiNode](/images/macos_setup_5_2e.png)

You should then see the 'digibyte@diginode' (or 'digibyte@diginode-testnet') prompt. You are now connected to your Pi. 

![SSH to DigiNode](/images/macos_setup_5_2f.png)

# NEXT: [STEP 6 - Run the DigiNode Setup script on your Raspberry Pi](/docs/rpi_setup_step6_run_diginode_setup.md)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).