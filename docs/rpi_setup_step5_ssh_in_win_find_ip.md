# DigiNode Setup Guide for the Raspberry Pi - Step-by-Step Instructions

Note: If you have not already connected the SSD to your Raspberry Pi and powered it on, then go [here](/docs/rpi_setup_step4_boot_pi.md) to complete STEP 4.

## STEP 5 - Connect to the Pi over SSH from Windows

If you don't already know the IP address of the Raspberry Pi, you may be able to discover it by logging into the web interface of your router and looking for it in the list of connected devices. (If you already know it, skip to step 5.5 below.) Alternatively, you can find it by using an IP address scanner, which is the method we will be using here. We will be uing 'Advanced IP Scanner'. It's free. 

If you already have 'Advanced IP Scanner' installed, open it now, and skip to step 5.4 below. 

### Step 5.3 - Install Advanced IP Scanner

Visit [https://www.advanced-ip-scanner.com/](https://www.advanced-ip-scanner.com/) in Microsoft Edge or Google Chrome and click the 'Free Download' button to download 'Advanced IP Scanner'.

![Download Advanced IP Scanner](/images/win_setup_5_3a.png)

If you are using Microsoft Edge, click on the 'Downloads' icon in the top-right corner of the browser window, and then click on the Advanced IP Scanner install file to open it.

![Open Advanced IP Scanner installer for Window - Edge](/images/win_setup_5_3b_edge.png)

If you are using Google Chrome, it will be in the downloads bar at the bottom of the window. Click on it to launch it.

![Open Advanced IP Scanner installer for Window - Chrome](/images/win_setup_5_3b_chrome.png)

When the window appears asking for permission for the app to make changes to your device, click 'Yes'.

![Install Advanced IP Scanner for Windows](/images/win_setup_5_3c.jpg)

Select your language and click 'Continue':

![Install Advanced IP Scanner for Windows](/images/win_setup_5_3d.png)

Select Install and click 'Next'.

![Install Advanced IP Scanner for Windows](/images/win_setup_5_3e.png)

Accept the Agreement and click 'Install'.

![Install Advanced IP Scanner for Windows](/images/win_setup_5_3f.png)

Once installation has finished, make sure 'Run Advanced IP Scanner' is ticked, and click 'Finish'.

![Install Advanced IP Scanner for Windows](/images/win_setup_5_3g.png)

Advanced IP Scanner will open.

### Step 5.4 - Lookup the IP address of the Raspberry Pi

Click the 'Scan' to scan the IP addresses on your local network.

![Start Scan in Advanced IP Scanner](/images/win_setup_5_4a.png)

Look through the results, and locate the 'diginode' hostname, and note its IP address. You should be able to identify it by also checking the Manufacturer column for 'Raspberry Pi Trading Ltd'.

![Scan Completed in Advanced IP Scanner](/images/win_setup_5_4b.png)

### Step 5.5 - Connect to the Raspberry Pi using SSH

Return to MobaXterm, and at the command prompt, enter the ssh command with the IP address from the previous step e.g. ```ssh digibyte@192.168.1.22```.

![SSH to DigiNode](/images/win_setup_5_5a.png)

At the next prompt, enter the password you created in STEP 3 and press return.

![SSH to DigiNode](/images/win_setup_5_5b.png)

It may prompt you to save the password, so you don't have to enter it every time.
 
![SSH to DigiNode](/images/win_setup_5_5c.png)

You are now connected to your Pi. You should see the 'digibyte@diginode' prompt. (or 'digibyte@diginode-testnet')

![SSH to DigiNode](/images/win_setup_5_5d.png)


# NEXT: [STEP 6 - Run the DigiNode Setup script on your Raspberry Pi](/docs/rpi_setup_step6_run_diginode_setup.md)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).