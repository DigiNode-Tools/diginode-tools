# DigiNode Setup on a Raspberry Pi - Instructions for macOS users

Note: These instructions are for MacOS users. If you are using Windows, please follow the instructions [here](docs/rpi_setup_win.md) Windows users..

## Before You Begin

A Raspberry Pi offers one of the easiest setups on which to run a dedicated DigiNode. A Raspberry Pi 4 8GB or better is recommended, booting from an SSD. For a complete list of suggested hardware, see [here](docs/suggested_hardware.md)

These instructions will take you though all the steps required to setup your DigiNode on a Raspberry Pi. They have been written with less technical users in mind, and should hopefully be easy for anyone to follow. If you get stuck, please join the [DigiNode Tools Telegram group](https://t.me/+ked2VGZsLPAyN2Jk) and ask for help.

## STEP 1 - Connect the DigiNode SSD to your computer

Depending on the type of enclosure you are using for your Raspberry Pi, you will either have an regular laptop 3.5" SSD in an external enclosure, or it will be 

## STEP 2 - Download and install the 'Raspberry Pi Imager' software

'Raspberry Pi Imager' will be used to "burn" the operating system on to the SSD you are going to booting the Rasperry Pi from.

### 2.1 - Download 'Raspberry Pi Imager'

Open Safari, and visit [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/) and click the 'Download for macOS' button to download the 'Raspberry Pi Imager' software to your computer

![Download Raspberry Pi Imager for macOS](/images/macos_setup_2_1.png)

### 2.2 - Install 'Raspberry Pi Imager'

Click on the 'Downloads' icon in the top-right corner of the Safari window, and then click on the downloaded 'imager_x.x.x.dmg' install file to open it.

![Open Raspberry Pi Imager installer for macOS](/images/macos_setup_2_2a.png)

Drag and drop the 'Raspberry Pi Imager' icon on to the Applications icon to install it in your Applications folder. 

![Install Raspberry Pi Imager for macOS](/images/macos_setup_2_2b.png)


## STEP 3 - Use 'Raspberry Pi Imager' to pre-configure and burn the operating system on to the SSD

Open 'Raspberry Pi Imager'. (You can double-click the 'Applications' shortcut icon from the previous step, to open your Applications folder, and then find the 'Rasperry Pi Imager' application that you just installed and double-click the icon to open it.)

### 3.1 - Choose Operating System: Raspberry Pi OS Lite (64-bit)

Click the 'CHOOSE OS' button:

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1a.png)

Click 'Raspberry Pi OS (other)':

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1b.png)

Scroll down and click 'Raspberry Pi OS Lite (64-bit):

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1c.png)

You should see 'RASPBERRY PI OS LITE (64-BIT) on the button. Make sure you have selected this version.

![Choose OS in Raspberry Pi Imager](/images/macos_setup_3_1d.png)

### 3.2 - Choose Storage: External SSD drive

Click the 'CHOOSE STORAGE' button:

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2a.png)

Select the external SSD you are going to use for your DigiNode. (Note: You should have already connected the SSD to your Mac in STEP 1. If you have not already done so, connect it now. It should show up in the list. If you still don't see it, try unplugging and reconnecting it. Once it appears, click on it to select it.)

!!! BE VERY CAREFUL TO SELECT THE CORRECT DRIVE: The contents of the drive will be completely erased in the next step !!!

(In this example, we are using a Samsung SSD. The system also has a Time machine backup drive connected.)

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2b.png)

You should now see the name of the external drive on the button. Double check it is correct.

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2c.png)

### 3.3 - Pre-configure your Raspberry Pi OS install

Before you begin writing the operating system to the SSD, you first want to pre-configure it. This will make it easy to connect to the system from your main computer when it first boots up, without needing a keyboard, mouse and display attached to the Raspberry Pi.

Click the cog icon:

![Choose Configure in Raspberry Pi Imager](/images/macos_setup_3_3a.png)

Next fill in the following options: (see screenshot below)

(1) For the hostname enter 'diginode' (or 'diginode-testnet' if you are planning to run a Digibyte testnet node).
    Make sure that the checkbox is ticked.

(2) You need to enable SSH so that you can remotely connect to the machine via the terminal when it first boots up.
    Select 'Use password autentication'.
    Make sure that the checkbox is ticked.

(3) Set the username to 'digibyte' and enter a password. Do not forget it. You will need it to connect to and manage your DigiNode.
	Make sure that the checkbox is ticked.

(4) Configuring the wireless LAN is optional. Since your DigiNode is a server that needs a robust connection
    to the internet, it is generally recommended to connect it to your router using a physical ethernet cable,
    whenever possible, rather than using a wifi connection. If you would like use wifi, enter your
    wifi network name (SSID), password and wireless LAN country here. Make sure that the checkbox is ticked.

(5) Set your timezone and keyboard layout, in case you ever need to connect one.

(6) 'Enable telemety' allows the Raspberry Pi Foundation to collect some anonymized data about
    your setup, primarily concerning which OS image you installed. It does not collect your
    IP address. You can disable this feature by unticking it.

More information about these settings can be found [here](https://talktech.info/2022/02/06/raspberry-pi-imager/).

Click SAVE when you are done.

![Configure image in Raspberry Pi Imager](/images/macos_setup_3_3b.png)