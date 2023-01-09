# Instructions for DigiNode Setup on a Raspberry Pi

## Before You Begin

A Raspberry Pi offers one of the easiest setups on which to run a dedicated DigiNode. A Raspberry Pi 4 8GB or better is recommended, booting from an SSD. For a complete list of suggested hardware, see [here](/docs/suggested_hardware.md).

These instructions will take you though all the steps required to setup your DigiNode on a Raspberry Pi. For less technical users, there is a link to more detailed instructions for each step, hopefully making it easy for everyone to follow.

If you get stuck, please join the [DigiNode Tools Telegram group](https://t.me/DigiNodeTools) and ask for help.

Note: A DigiNode is designed to operate "headless". This means you do not need a display, keyboard or mouse attached to your Raspberry Pi. Your DigiNode will be entirely managed from your Mac or Windows computer.

## Summary of Steps

You will need to complete the following steps to setup your DigiNode on a Raspberry Pi:

1. Connect the SSD you will be using with your Raspberry Pi to your Mac or Windows computer.
2. Use 'Raspberry Pi imager' to pre-configure the Raspberry Pi operating system and write it to the SSD.
3. Connect the SSD to the Raspberry Pi, along with power and ethernet cable (if using) and power it on.
4. Once the Pi has booted up, connect to the system remotely from your Mac or Windows PC using SSH and run the DigiNode Setup script.
5. Assign the Raspberry Pi a fixed IP address on your network and open the relevant ports on your router.

## STEP 1 - Connect the SSD to your Windows or Mac computer

If you are using an external SSD you should be able to use the cable it came with to plug it directly into your computer. 

If you are using a case with an internal SSD, you may need to purchase a cable for this purpose if you don't already have one. You will need a [USB-A to USB-A cable](https://amzn.to/3GMWzs3), or [USB-A to USB-C cable](https://amzn.to/3ik2trg), depending on the type of USB port available on your computer.

More detailed instructions on completing this step are [here](/docs/rpi_setup_step1_connect_ssd.md).

## STEP 2 - Download and install the 'Raspberry Pi Imager' software

Go to the Raspberry Pi website, and download and install the 'Raspberry Pi imager' software on to your computer.

You can find it here: [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/)

More detailed instructions on completing this step are [here](/docs/rpi_setup_step2_get_imager_win.md) for Windows and [here](/docs/rpi_setup_step2_get_imager_mac.md) for Mac.

## STEP 3 - Use 'Raspberry Pi Imager' to pre-configure the operating system and write it to the SSD

Open 'Raspberry Pi Imager' if it is not already running. 

Make sure you are running Raspberry Pi Imager v1.7.3 or newer.

![Raspberry Pi Imager v1.7.3](/images/macos_setup_3_mm.png)

- Click 'CHOOSE OS' and select: **Raspberry Pi OS Lite (64-bit)**
- Click 'CHOOSE STORAGE' and select the SSD you are using for your DigiNode.

Click the cog icon, to open the advanced options menu:

![Configure image in Raspberry Pi Imager](/images/macos_setup_3_3b.png)

1. For the hostname enter 'diginode' (or 'diginode-testnet' if you are planning to run a DigiByte testnet node).
2. Enable SSH and select 'Use password autentication'.
3. Set the username to 'digibyte' and enter a password. (Don't forget it! You will need it to mage your DigiNode.)
4. Configuring the wireless LAN is optional. Using an ethernet cable is prefereable.
5. Set your timezone and keyboard layout, in case you ever need to connect one.
6. 'Enable telemety' allows the Raspberry Pi Foundation to collect some anonymized data about
    your setup. It does not collect your IP address. You can disable this feature by unticking it.

More information about all these settings can be found [here](https://talktech.info/2022/02/06/raspberry-pi-imager/).

Click SAVE when you are done, and then click WRITE to begin burning the image to the SSD. It'll take a few minutes.

More detailed instructions on completing this step are [here](/docs/rpi_setup_step3_write_os.md).

## STEP 4 - Connect the SSD to the Raspberry Pi, along with power and ethernet cable (if using) and power it on

- Connect the SSD to one of the blue USB3 ports on the Raspberry Pi.
- Plug in an ethernet cable that is connected to your router. (unless you are using wifi)
- Connect a genuine Raspberry Pi PSU and power on the device.
- Wait a minute or two while it boots for the first time.

More detailed instructions on completing this step are [here](/docs/rpi_setup_step4_boot_pi.md).

## STEP 5 - Connect to the Pi over SSH from your Mac or PC

- If are on a Mac, using [iTerm 2](https://iterm2.com/) is highly recommended.

Connect to your DigiNode using the command: ```ssh digibyte@diginode.local```

If this does not find your Raspberry Pi, you will need to connect using its IP address. If you don't know what it is, you may be able to find it by logging into the web interface of your router and looking for it in the list of connected devices. Alternatively, you can use an IP address scanner such as [Angry IP Scanner](https://angryip.org/) (Windows & macOS) or [LanScan](https://www.iwaxx.com/lanscan/) (macOS)

More detailed instructions on completing this step are [here](/docs/rpi_setup_step5_ssh_in_win.md) for Windows and [here](/docs/rpi_setup_step5_ssh_in_mac.md) for Mac.

## STEP 6 - Run DigiNode Setup