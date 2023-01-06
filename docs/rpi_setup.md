# Instructions to Setup a DigiNode on a Raspberry Pi

## Before You Begin

A Raspberry Pi offers one of the easiest setups on which to run a dedicated DigiNode. A Raspberry Pi 4 8GB or better is recommended, booting from an SSD. For a complete list of suggested hardware, see [here](/docs/suggested_hardware.md).

These instructions will take you though all the steps required to setup your DigiNode on a Raspberry Pi. For less technical users, there is a link to more detailed instructions for each step, hopefully making it easy for everyone to follow. If you get stuck, please join the [DigiNode Tools Telegram group](https://t.me/+ked2VGZsLPAyN2Jk) and ask for help.

## Summary of Steps

You will need to complete the following steps to setup your DigiNode on a Raspberry Pi:

1. Connect the SSD you will be using with your Raspberry Pi to your Mac or Windows computer
2. Use 'Raspberry Pi imager' to write the Raspberry Pi Operating System to the SSD
3. Connect the SSD to the Raspberry Pi, along with power and ethernet cable (if using) and power it on
4. Once the Pi has booted, SSH into it from your Mac or PC and run the DigiNode Setup scrript.

## STEP 1 - Connect the SSD to your Windows or Mac computer

To install the operating system for your DigiNode, you need to connect the SSD you are using with your Raspberry Pi to your Mac or Windows computer. You can then use the 'Raspberry Pi Imager' software to write the operating system on to the SSD.

If you are using an external SSD you should be able to use the cable it came with to plug it directly into your computer. 

If you are using an internal SSD, you may need to purchase a cable for this purpose if you don't already have one. You will need a USB-A to USB-A cable, or USB-A to USB-C cable, depending on the USB ports you have on your computer.

More detailed instructions on completing this step are [here](/docs/rpi_setup_step1_connect_ssd.md).

## STEP 2 - Download and install the 'Raspberry Pi Imager' software

Go to the Raspberry Pi website, and download and install the 'Raspberry Pi imager' software on to your computer.

You can find it here: [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/)

More detailed instructions on completing this step are [here](/docs/rpi_setup_step2_get_imager_win.md) for Windows and [here](/docs/rpi_setup_step2_get_imager_mac.md) for Mac.

## STEP 3 - Use 'Raspberry Pi Imager' to pre-configure and burn the operating system on to the SSD

Open 'Raspberry Pi Imager' if it is not already running. 

Make sure you are running Raspberry Pi Imager v1.7.3 or newer.

![Raspberry Pi Imager v1.7.3](/images/macos_setup_3.png)

- Click 'CHOOSE OS' and select: **Raspberry Pi OS Lite (64-bit)**
- Click 'CHOOSE STORAGE' and select the SSD you are using for your DigiNode.

Click the cog icon, to open the advanced menu:

![Configure image in Raspberry Pi Imager](/images/macos_setup_3_3b.png)

1. For the hostname enter 'diginode' (or 'diginode-testnet' if you are planning to run a Digibyte testnet node).
2. Enable SSH and select 'Use password autentication'.
3. Set the username to 'digibyte' and enter a password. 
4. Configuring the wireless LAN is optional. Using an ethernet cable is prefereable.
5. Set your timezone and keyboard layout, in case you ever need to connect one.
6. 'Enable telemety' allows the Raspberry Pi Foundation to collect some anonymized data about
    your setup. It does not collect your IP address. You can disable this feature by unticking it.

More information about all these settings can be found [here](https://talktech.info/2022/02/06/raspberry-pi-imager/).

Click SAVE when you are done, then click WRITE to begin burning the image to the SSD. Grab a coffee while it does its thing.

More detailed instructions on completing this step are [here](/docs/rpi_setup_step1_connect_ssd.md).

## STEP 4 - Connect the SSD to the Raspberry Pi amd power it on

- Connect the SSD to one of the blue USB3 ports on the Raspberry Pi.
- Plug in an ethernet cable that is connected to your router. (unless you are using wifi)
- Connect a genuine Raspberry Pi PSU and power on the device.
- Wait a minute or two while it boots for the first time.

## STEP 5 - Connect to the Pi over SSH from your Mac or PC

- If are on a Mac, using [iTerm 2](https://iterm2.com/) is highly recommended.

Connect to your DigiNode using the command:

```ssh digibyte@diginode.local```

If this does not find your Pi, you may need to lookup its IP address and connect that way.

## STEP 6 - Run DigiNode Setup