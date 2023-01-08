# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not already connected the SSD to your Raspberry Pi and powered it on, then please go [here](/docs/rpi_setup_step4_boot_pi.md) and complete STEP 4.

## STEP 5 - Connect to the Pi over SSH from macOS

You will now connect to the Raspberry Pi from your main computer using SSH (Secure Shell). You will then be able to run the DigiNode Setup script.

(Note: The instructions on this page are for macOS. If you on Windows, click [here](/docs/rpi_setup_step5_ssh_in_win.md).)

### Step 5.1 - Download and install 'iTerm 2'

Rather than using the the built-in Terminal app to connect to your Raspberry Pi, it is recommended to use 'iTerm 2' which has better support for the text formatting used by DigiNode Tools.

Open Safari, and visit [https://iterm2.com/](https://iterm2.com/) and click the 'Download' button to download 'iTerm 2'.

![Download iTerm 2](/images/macos_setup_5_1a.png)

If asked to allow downloads, click 'Allow':

![Download iTerm 2](/images/macos_setup_5_1b.png)

Click on the 'Downloads' icon in the top-right corner of the Safari window, and then click on the magnifying glass icon next to the 'iTerm' download to open the Downloads folder.

![Download iTerm 2](/images/macos_setup_5_1c.png)

To install iTerm 2, drag-and-drop it on to the Applications folder.

![Install iTerm 2](/images/macos_setup_5_1d.gif)

### Step 5.2 - Connect to the Raspberry Pi using SSH

Launch iTerm 2. (You can do this by pressing '⌘ + Space' to open Spotlight search, then type 'iterm' and press enter.)

![Launch iTerm 2](/images/macos_setup_5_2a.png)

If you see the warning message, click 'Open'.

![Launch iTerm 2](/images/macos_setup_5_2b.png)

At the command prompt in iTerm 2, type ```ssh digibyte@diginode.local``` and press return to connect to the Raspberry Pi.

(If you set the hostname to 'diginode-testnet', use ```ssh digibyte@diginode-testnet.local```)

![SSH to DigiNode](/images/macos_setup_5_2c.png)



# NEXT: [STEP 6 - Run the DigiNode Setup script](/docs/rpi_setup_step6_run_diginode_setup.md)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).