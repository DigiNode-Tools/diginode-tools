# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not already installed the 'Raspberry Pi Imager' software, please complete STEP 2 first. Click [here](/docs/rpi_setup_step2_get_imager_win.md) if you are on Windows, and [here](/docs/rpi_setup_step2_get_imager_mac.md) for Mac.

Note: The screenshots on this page show the Mac version, but the software is the same if you are on Windows.

## STEP 3 - Use 'Raspberry Pi Imager' to pre-configure the operating system and write it to the SSD

If it is not already running, open 'Raspberry Pi Imager'. Check you are using v1.7.3 or newer.

![Raspberry Pi Imager v1.7.3](/images/macos_setup_3.png)

### Step 3.1 - Choose Operating System: Raspberry Pi OS Lite (64-bit)

Click the 'CHOOSE OS' button:

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1a.png)

Click 'Raspberry Pi OS (other)':

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1b.png)

Scroll down and click 'Raspberry Pi OS Lite (64-bit):

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1c.png)

You should see 'RASPBERRY PI OS LITE (64-BIT) on the button. 

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1d.png)

IMPORTANT: Make sure you have selected the correct version of Raspberry Pi OS - it must be the LITE edition (includes no desktop OS), and must be 64-bit (the 32-bit OS will not work).

### Step 3.2 - Choose Storage: External SSD drive

Click the 'CHOOSE STORAGE' button:

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2a.png)

Select the external SSD you are going to use for your DigiNode. 

(Note: You should have already connected the SSD to your Mac in STEP 1. If you have not already done so, connect it now. It should show up in the list. If you still don't see it, try unplugging and reconnecting it. Once it appears, click on it to select it.)

***!!! BE VERY CAREFUL TO SELECT THE CORRECT DRIVE: The contents of the drive will be completely erased in the next step !!!***

(In this example, we are using a Samsung SSD. The system also has a Time Machine backup drive connected.)

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2b.png)

You should now see the name of the external drive on the button. Double check it is correct.

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2c.png)

### Step 3.3 - Pre-configure your Raspberry Pi OS install

Before you begin to write the operating system to the SSD, you first want to pre-configure it. This will make it easy to connect to the system from your main computer when it first boots up, without needing a keyboard, mouse and display attached to the Raspberry Pi.

Click the cog icon:

![Choose Configure in Raspberry Pi Imager](/images/macos_setup_3_3a.png)

You will see the advanced settings menu:

![Configure image in Raspberry Pi Imager](/images/macos_setup_3_3b.png)

Next fill in the following options:

1. For the hostname enter 'diginode' (or 'diginode-testnet' if you are planning to run a Digibyte testnet node). Make sure that the checkbox is ticked.
2. You need to enable SSH so that you can remotely connect to the machine via the terminal when it first boots up. Select 'Use password autentication'. Make sure that the checkbox is ticked.
3. Set the username to 'digibyte' and enter a password. Do not forget it. You will need it to connect to and manage your DigiNode. Make sure that the checkbox is ticked.
4. Configuring the wireless LAN is optional. Since your DigiNode is a server that needs a robust connection to the internet, it is generally recommended to connect it to your router using a physical ethernet cable, whenever possible, rather than using a wifi connection. If you would like use wifi, enter your wifi network name (SSID), password and wireless LAN country here. Make sure that the checkbox is ticked.
5. Set your timezone and keyboard layout, in case you ever need to connect one.
6. 'Enable telemety' allows the Raspberry Pi Foundation to collect some anonymized data about your setup, primarily concerning which OS image you installed. It does not collect your IP address. You can disable this feature by unticking it.

More information about all these settings can be found [here](https://talktech.info/2022/02/06/raspberry-pi-imager/).

Click SAVE when you are done.

### Step 3.4 - Write the OS to the SSD

Click WRITE to begin writing the operating system to the SSD. 

![Write OS in Raspberry Pi Imager](/images/macos_setup_3_4a.png)

It will ask you to confirm erasing the contents of the SSD.

***!!! BE VERY CAREFUL YOU HAVE SELECTED THE CORRECT DRIVE !!!***

Click YES to continue.

![Write OS in Raspberry Pi Imager](/images/macos_setup_3_4b.png)

If you are on a Mac, it will prompt you for your system password. (The password you enter when you sit down at your computer.) 
Enter it now and click 'OK'.

![Write OS in Raspberry Pi Imager](/images/macos_setup_3_4c_mac.png)

Raspberry Pi Imager will now download the operating system image file and write it to the SSD. Go grab a coffee. This may take a few minutes.

![Write OS in Raspberry Pi Imager](/images/macos_setup_3_4d.png)

![Verify OS in Raspberry Pi Imager](/images/macos_setup_3_4e.png)

If all goes to plan you should see this message:

![OS Written in Raspberry Pi Imager](/images/macos_setup_3_4f.png)

You can now click 'Continue', close Raspberry Pi imager, and disconnect the SSD from your computer.

# NEXT: [STEP 4 - Connect the SSD to the Raspberry Pi, along with power and ethernet cable (if using) and power it on](/docs/rpi_setup_step4_boot_pi.md)

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).