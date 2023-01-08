# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not already setup the operating system on the SSD, then please go [here](/docs/rpi_setup_step3_write_os.md) and complete STEP 3.

## STEP 4 - Connect the SSD to the Raspberry Pi, along with power and ethernet cable (if using) and power it on

Connect the SSD to one of the free USB 3.0 ports on the the Raspbery Pi 4:

![Raspberry Pi Ports](/images/pi4_ports.png)

If you have a case where the SSD is inside it, such as the 'Argon M.2 One', then use the provided U-shaped USB dongle to connect the SSD to the lower USB 3.0 port on the Raspberrry Pi.

![Raspberry Pi Ports](/images/argon_m2_usb.jpg)

Next, connect an Ethernet cable, unless you are using wifi. Using an Ethernet cable is the preferred method. Plug one end of the cable in to the Gigabit Ethernet port on the Raspberry Pi, and plug the other end into a free port on the back of your router.

Finally, connect the power supply to the USB-C power port, and switch it on. If your case has a power button, you may need to press it. 

IMPORTANT: It is highly recommeneded that you use a Genuine Raspberry Pi 4 PSU. Third-party power supplies can sometimes have voltage issues, and have been known to cause problems.

The Raspberry Pi should now boot from the SSD. The first time you do this, the operating system will need to configure itself and it will take a few minutes to complete.


# NEXT: STEP 5 - Connect to the Pi over SSH from your Mac or Windows PC
Click [here](/docs/rpi_setup_step5_ssh_in_win.md) if you using Windows. Click [here](/docs/rpi_setup_step5_ssh_in_mac.md) if you are on a Mac.

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).