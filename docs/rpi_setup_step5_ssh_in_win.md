# DigiNode Setup Guide for the Raspberry Pi - Step-by-Step Instructions

Note: If you have not already connected the SSD to your Raspberry Pi and powered it on, then please go [here](/docs/rpi_setup_step4_boot_pi.md) and complete STEP 4.

## STEP 5 - Connect to the Raspberry Pi from your Windows PC

You will now connect to the Raspberry Pi from your Windows computer using SSH (Secure Shell). You will then be able to run the DigiNode Setup script.

(Note: The instructions on this page are for Windows. If you on macOS, click [here](/docs/rpi_setup_step5_ssh_in_mac.md).)

### Step 5.1 - Download and install 'MobaXterm'

To connect to your Raspberry Pi from Windows you need to install an SSH client. MobaXterm is an excellent choice since it supports the advanced text formatting used by DigiNode Tools. It's free.

Visit [https://mobaxterm.mobatek.net/](https://mobaxterm.mobatek.net/) in Microsoft Edge or Google Chrome and click the 'GET MOBAXTERM NOW!' button to download it.

![Download MobaXterm](/images/win_setup_5_1a.png)

Under 'Home Edition', click 'Download Now'.

![Download MobaXterm](/images/win_setup_5_1b.png)

Click the button for 'MobaXterm Home Edition v22.3 (Installer edition)'

![Download MobaXterm](/images/win_setup_5_1c.png)

If you are using Microsoft Edge, click on the 'Downloads' icon in the top-right corner of the browser window, and then click on the MobaXterm install zip file to open it.

![Open MobaXterm zip for Windows - Edge](/images/win_setup_5_1d_edge.png)

If you are using Google Chrome, it will be in the downloads bar at the bottom of the window. Click on it to launch it.

![Open MobaXterm zip for Windows - Chrome](/images/win_setup_5_1d_chrome.png)

Click the 'Extract All' button to unzip the install files.

![Extract MobaXterm zip for Windows](/images/win_setup_5_1e.png)

Click the 'Extract' button. Make sure that the 'Show extracted files when complete' checkbox is ticked.

![Extract MobaXterm zip for Windows](/images/win_setup_5_1f.png)

Double-click the MobaXterm msi install file to launch it.

![Extract MobaXterm zip for Windows](/images/win_setup_5_1g.png)

When the window appears asking for permission for the app to make changes to your device, click 'Yes'.

![MobaXterm Permission Windows](/images/win_setup_5_1h.jpg)

Click Next.

![Install MobaXterm zip for Windows](/images/win_setup_5_1i.png)

Click Next.

![Install MobaXterm zip for Windows](/images/win_setup_5_1j.png)

Click Next.

![Install MobaXterm zip for Windows](/images/win_setup_5_1k.png)

Click Install.

![Install MobaXterm zip for Windows](/images/win_setup_5_1l.png)

Click Finish.

![Install MobaXterm zip for Windows](/images/win_setup_5_1m.png)

### Step 5.2 - Connect to the Raspberry Pi using SSH

Launch MobaXterm. (Click on Start and then click on the MobaXterm icon.)

![Launch MobaXterm](/images/win_setup_5_2a.png)

If you see the Winodws Security Alert dialog, tick 'Private networks' and click 'Allow Access'.

![Allow Private Networks for MobaXterm](/images/win_setup_5_2b.png)

Click 'Start Local Terminal'.

![Start Local Termnal in MobaXterm](/images/win_setup_5_2c.png)

At the command prompt in MobaXterm, type ```ssh digibyte@diginode.local``` and press return to connect to the Raspberry Pi.

(If you set the hostname to 'diginode-testnet', use ```ssh digibyte@diginode-testnet.local```)

![SSH to DigiNode](/images/win_setup_5_2d.png)

(NOTE: If it is unable to find your Raspberry Pi on your local network, it may get stuck on the screen above - press 'Ctrl + C' to cancel. In this event, you will need to connect using the IP address of the Pi instead. e.g. ```ssh digibyte@192.168.1.10```. If you don't already know the IP address, go [here](/docs/rpi_setup_step5_ssh_in_win_find_ip.md) for instructions on how to find it.)

When prompted, enter the password you created in STEP 3 and press return.

![SSH to DigiNode](/images/win_setup_5_2e.png)

It may prompt you to save the password, so you don't have to enter it every time.
 
![SSH to DigiNode](/images/win_setup_5_2f.png)

You should then see the 'digibyte@diginode' (or 'digibyte@diginode-testnet') prompt. You are now connected to your Pi. 

![SSH to DigiNode](/images/win_setup_5_2g.png)

# NEXT: [STEP 6 - Run the DigiNode Setup script on your Raspberry Pi](/docs/rpi_setup_step6_run_diginode_setup.md)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).