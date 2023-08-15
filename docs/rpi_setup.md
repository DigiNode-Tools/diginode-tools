# DigiNode Setup Guide for the Raspberry Pi

## Before You Begin

- A Raspberry Pi is arguably the easiest way to run a DigiNode.
- A **Raspberry Pi 4 8GB** or better is recommended, **booting from an SSD**. (Using a microSD is significantly slower and less robust.) For suggested hardware, click [here](/docs/suggested_hardware.md).
- DigiNode is designed to operate headless - i.e. you do not need a display, keyboard or mouse attached to your Raspberry Pi. Everything is managed remotely from your computer.
- This page covers all the steps to setup a DigiNode on your Raspberry Pi. For less technical users, there are links to more detailed step-by-stop instructions.
- For help, join the [DigiNode Tools Telegram group](https://t.me/DigiNodeTools).

## Summary of Steps

You will need to complete the following steps to setup your DigiNode on a Raspberry Pi:

1. Assemble your case and connect the SSD you will be using with your Raspberry Pi to your Mac or Windows PC.
2. Download and install 'Raspberry Pi Imager' from the Raspberry Pi website.
3. Use 'Raspberry Pi imager' to pre-configure the Raspberry Pi operating system and write it to the SSD.
4. Connect the SSD to the Raspberry Pi, along with power and ethernet cable (if using).
5. Power on the Pi and connect to it remotely from your Mac or Windows PC using SSH.
6. Run the DigiNode Setup script to install and configure your DigiByte Node and/or DigiAsset Node.
7. Assign the Raspberry Pi a Static IP address on your network and open the relevant ports on your router.

## STEP 1 - Assemble the Raspberry Pi in its case and connect the SSD to your Windows or Mac computer

- Assemble the Raspberry Pi in its case.
- If your case has a power button, set the jumper to have it start up automatically. This will ensure your DigiNode restarts automatically after a power outage. (See the instructions that came with your case for how to do this.)
- Connect the SSD to your computer (Windows or Mac). With an external SSD, plug it directly into your computer with the cable it came with. With an internal SSD, you will need a [USB-A to USB-A cable](https://amzn.to/3GMWzs3) or [USB-A to USB-C cable](https://amzn.to/3ik2trg), depending on the type of USB port available on your computer.

*Need more help completing Step 1? Click [here](/docs/rpi_setup_step1_connect_ssd.md) for detailed step-by-step instructions.*

## STEP 2 - Download and install the 'Raspberry Pi Imager' software

- Download and Install Raspberry Pi Imager: https://www.raspberrypi.com/software/

*Need more help completing Step 2? For detailed step-by-step instructions, click [here](/docs/rpi_setup_step2_get_imager_win.md) for Windows and [here](/docs/rpi_setup_step2_get_imager_mac.md) for Mac.*

## STEP 3 - Use 'Raspberry Pi Imager' to pre-configure the operating system and write it to the SSD

- Launch 'Raspberry Pi Imager' if it is not already running. Check it is v1.7.3 or newer:

![Raspberry Pi Imager v1.7.3](/images/macos_setup_3_mm.png)

- Click 'CHOOSE OS' and select: **Raspberry Pi OS Lite (64-bit)**
- Click 'CHOOSE STORAGE' and select the SSD you are using for your DigiNode.
- Click the COG ICON, to open the advanced options menu:

![Configure image in Raspberry Pi Imager](/images/macos_setup_3_3b.png)

1. For the hostname enter 'diginode' (or 'diginode-testnet' if you are planning to run a DigiByte testnet node).
2. Enable SSH and select 'Use password authentication'.
3. Set the username to 'digibyte' and enter a password. (Don't forget it! You will need it to manage your DigiNode.)
4. Configuring the wireless LAN is optional. Using an ethernet cable is prefereable.
5. Set your timezone and keyboard layout, in case you ever need to connect one.
6. 'Enable telemety' allows the Raspberry Pi Foundation to collect some anonymized data about
    your setup, such as which OS yout installed. It does not collect your IP address. You can disable this feature by unticking it.

More information about all these settings can be found [here](https://talktech.info/2022/02/06/raspberry-pi-imager/).

- Click SAVE when you are done
- Click WRITE to begin burning the image to the SSD. It'll take a few minutes.

*Need more help completing Step 3? Click [here](/docs/rpi_setup_step3_write_os.md) for detailed step-by-step instructions.*

## STEP 4 - Connect the SSD to the Raspberry Pi, along with power and ethernet cable (if using) and power it on

- Connect the SSD to one of the blue USB3 ports on the Raspberry Pi.
- Plug in an ethernet cable that is connected to your router. (unless you are using wifi)
- Connect a genuine Raspberry Pi PSU and power on the device.
- Wait a minute or two while it boots for the first time.

*Need more help completing Step 4? Click [here](/docs/rpi_setup_step4_boot_pi.md) for detailed step-by-step instructions.*

## STEP 5 - Connect to the Raspberry Pi from your Mac or Windows PC

- To connect to your Raspberry Pi, you need a terminal emulator. If are on a Mac, using [iTerm 2](https://iterm2.com/) is highly recommended, and for Windows, [MobXterm](https://mobaxterm.mobatek.net/).
- Connect to your DigiNode using the command: ```ssh digibyte@diginode.local``` (If you set the hostname to 'diginode-testnet', use ```ssh digibyte@diginode-testnet.local```)

If this does not find your Raspberry Pi, you will need to connect using its IP address - e.g. ```ssh digibyte@192.168.1.10```. Find the IP address via the web interface of your router under the list of connected devices. Alternatively, use an IP address scanner such as [Advanced IP Scanner](https://www.advanced-ip-scanner.com/) (Windows) or [LanScan](https://apps.apple.com/gb/app/lanscan/id472226235?mt=12) (macOS).

*Need more help completing Step 5? For detailed step-by-step instructions, click [here](/docs/rpi_setup_step5_ssh_in_win.md) for Windows and [here](/docs/rpi_setup_step5_ssh_in_mac.md) for Mac.*

## STEP 6 - Run the DigiNode Setup script on your Raspberry Pi

- Launch DigiNode Setup by entering: ```curl -sSL setup.diginode.tools | bash```
- Follow the on-screen instructions to complete the setup process. 
- IMPORTANT: In DigiByte Core v7.17.3 there is a bug which means you cannot effectively run a testnet node on a Raspberry Pi. This will be fixed in v8. For now, only run a mainnet node on the Pi.

*Need more help completing Step 6? Click [here](/docs/rpi_setup_step6_run_diginode_setup.md) for detailed step-by-step instructions.*

## STEP 7 - Give the Raspberry Pi a Static IP address and setup Port Forwarding

- To make it easy to access your DigiNode on your local network, it is recommended to give your Raspberry Pi a Static IP address. This can typically be done via the web interface of your router. 
- Enable port forwarding to make your device discoverable by other nodes. This step is very important if you want to help support the network.

If you setup a mainnet DigiNode, the default ports you need to forward are:
- DigiByte Core: **12024**
- IPFS: **4001**

If you setup a testnet DigiNode, the default ports you need to forward are:
- DigiByte Core: **12026**
- IPFS: **4004**

*Need more help completing Step 7? Click [here](/docs/rpi_setup_step7_forward_ports.md) for detailed step-by-step instructions.*

## STEP 8 - Install case fan software (if needed)

- The software for the 'Argon One M.2' case can be installed directly from the 'DigiNode Setup' main menu. Run ```diginode-setup``` and find it under 'Extras'.