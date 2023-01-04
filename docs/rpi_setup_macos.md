# DigiNode Setup on Raspperry Pi - Instructions for macOS Users

Note: These instructions are for MacOS users. If you are using Windows, please follow the instructions here.

## Before You Begin

A Raspberry Pi offers one of the easiest setups on which to run a dedicated DigiNode. A Raspberry Pi 4 8GB or better is recommended, booting from an SSD. For a complete list of suggested hardware, see [here](docs/suggested_hardware.md)

These instructions will take you though all the steps required to setup your DigiNode on a Raspberry Pi 4 or better. They have been written with less technical users in mind, and should hopefully be easy for anyone to follow. If you get stuck, please join the [DigiNode Tools Telegram group](https://t.me/+ked2VGZsLPAyN2Jk) and ask for help.

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

Double click the 'Applications' shortcut icon from the previous step, to open your system Applications folder. Find the 'Rasperry Pi Imager' application that you just installed and double-click the icon to open it.

![Raspberry Pi Imager for macOS](/images/macos_setup_3.png)

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

Select the external SSD you are going to use for your DigiNode SSD. (If you have not already connected it to your computer, do so now. It will show up in the list.)

!!! BE VERY CAREFUL: Make sure you have selected the correct SSD as the contents of the drive will be erased in the next step !!!

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2b.png)

You should now see the name of the external drive on the button. Double check it is correct.

![Choose Storage in Raspberry Pi Imager](/images/macos_setup_3_2c.png)