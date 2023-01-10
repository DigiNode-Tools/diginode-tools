# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

Note: If you have not already connected the SSD to your Raspberry Pi and powered it on, then go [here](/docs/rpi_setup_step4_boot_pi.md) to complete STEP 4.

## STEP 5 - Connect to the Pi over SSH from macOS

You may be able to discover the IP address of the Raspberry Pi by logging into the web interface of your router and looking for it in the list of connected devices. If you already know the IP address to the Raspberry Pi, skip to step 5.5 below. Alternatively, you can use an IP address scanner, which is the method we will be using here. We will be uing 'LanScan' available from the Mac App Store. The basic version is free. If you already have this installed, open it now, and skip to step 5.4 below. 

### Step 5.3 - Install LanScan IP Network Scanner

Click [here](https://apps.apple.com/gb/app/lanscan/id472226235?mt=12) to open the LanScan page in the Mac App Store.

Click on the blue 'Get' button. (It may also be labelled 'Install' or 'Update' if you have used LanScan before.)

Note: If the button says 'Open' then the current version of LanScan is already installed. Click it and skip to Step 5.4 below.

![Install LanScan](/images/macos_setup_5_3a.png)

Enter your Apple ID and password, if prompted.

![Enter Apple ID and password](/images/macos_setup_5_3b.png)

You may also be prompted for your payment information. You will need to provide this to download Apps from the Mc App Store, even though this version of LanScan is free.

LanScan will then be downloaded. Once it has finished installing, click the 'Open' button, to launch LanScan.

![Open LanScan](/images/macos_setup_5_3c.png)

### Step 5.4 - Lookup  the IP address of the Raspberry Pi

Click the 'Start LanScan' to scan the IP addresses on your local network.

![Start Scan in LanScan](/images/macos_setup_5_4a.png)

Look through the results, and locate the DigiNode hostname, and note its IP address. If you have the free version of LanScan the DigiNode hostname will only display the first three letters - e.g. 'dig***'. You should be able to identify it by also checking the Vendor column for 'Raspberry Pi Trading Ltd'. If nneeded, you can upgrade to the Pro edition of LanScan but it shouldn't be necessary.

![Scan Completed in Angry IP Scanner](/images/macos_setup_5_4b.png)

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