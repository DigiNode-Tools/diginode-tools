# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

## STEP 1 - Assemble the Raspberry Pi in its case and connect the SSD to your Windows or Mac computer

### Step 1.1 Assemble your Raspberry Pi in its case

If you have not already done so, assemble your Raspberry Pi in its case.

Note: If your Raspberry Pi case has a power button, it may also have an option to boot automatically when the power is connected, rather than you having to press the power button. If so, it would be a good idea to enable it to ensure that your DigiNode will always startup automatically after a power outage.  Please refer to the instructions that came with your Pi case for how to do this - typically it involves changing a jumper pin on the board for the case.

### Step 1.2 Connect the SSD to your computer

To install the operating system for your DigiNode, you will first need to connect the SSD you are using with your Raspberry Pi to your computer. You can then use the 'Raspberry Pi Imager' software to write the operating system on to the SSD.

Depending on the type of enclosure you are using for your Raspberry Pi, your SSD will either be in an external case like have an SSD in a seperate external case, or it is built

**External SSD**

If you are using an external SSD you should be able to use the cable(s) that it came with to plug it directly into your computer. 

![SSD Enclosures](/images/ssd_enclosures.png)

**Internal SSD**

Some Raspberry Pi cases, such as the 'Argon ONE M.2' or the 'DeskPi Pro' have space for an SSD within the case. The SSD is then connected to the USB port the Raspberry Pi by way of a U-shaped USB dongle.

To connect the internal SSD to your computer you will need a USB cable to connect it. Newer Macs and PCs frequently only have USB-C ports these days, so you may need a [USB-C to USB-A cable](https://amzn.to/3ik2trg) to connect the SSD. If your computer is older and has USB-A ports (the big rectangular one), you will need a [USB-A to USB-A](https://amzn.to/3GMWzs3) cable.

![USB Cable Types](/images/usb_cable_types.png)

In the case of the Argon M.2 One case (see image below), you need to connect one end of the cable to the USB-A port of the internal SSD. Then connect the other end of the cable to your Mac.

![USB port for the internal SSD on the Argon M.2 One case](/images/argon_case_ports_ssd.jpg)


# NEXT: STEP 2 - Download and Install the 'Raspberry Pi Imager' software. 
Click [here](/docs/rpi_setup_step2_get_imager_win.md) if you on Windows and [here](/docs/rpi_setup_step2_get_imager_mac.md) if you are on Mac.

To return to the less detailed instructions, click [here](/docs/rpi_setup.md).