# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not already completed DigiNode Setup on your Raspberry Pi, then please go [here](/docs/rpi_setup_step6_run_diginode_setup.md) and complete STEP 6.

## STEP 7 - Give your DigiNode a static IP address, and setup port forwarding

### A Brief Primer on IP Addresses

Every single device on your home network can be identified by its IP addresses. By default, your router assigns a dynamic IP Address to every device that connects to it. This is managed by the DHCP (Dynamic Host Control Protocol) server that is built in to the router. Each device connected to your network can maintain its lease on the IP address it has been allocated by the DHCP server, but if it disappears from the network, the IP address is eventually released for another device to use.

IP addresses on a local network are typically in the range from 192.168.1.1 to 192.168.1.254. The router itself will usually take one of these (usually 192.168.1.1 or 192.168.1.254) and will then have DHCP allocate all or some of the remaining addresses for use by the other devices on your network.

Sometimes it can be benficial for a device to always have the same IP address (i.e. a Static IP address) when it connects to the network. In the case of the DigiNode, this means you will always be able to easily locate it on your network at the same IP address.

In order to assign a static IP address to your DigiNode device, and to forward the required ports, you will need to gain access to your router's management area.

### Step 7.1 - Login to the web interface of your router

Before trying to access your router, make sure the computer you are using is connected to the same network. It should be connected to your router's wifi, or be plugged into it with a network cable. 

Built into almost all routers is a web interface that can be used to manage it. (A notable exception is Apple's dicontinued Airport devices that use the 'Airport Utility' app to manage them.). The IP address, username and password to access this varies depending on your router manufacturer. In most cases, there is usually a sticker on the router itself telling you how to connect to it, similar to the example below.

![Router Label](/images/router_label.jpg)

The sticker on your router, will hopefully tell you the web address or IP address to access the admin page, along with the username and password. If it does not include these, try googling your router make and model to find out the default username and password.

You can also try visiting: http://whatsmyrouterip.com/

Once you have found the login credentials, enter the IP address or web address into your browser, and then login to the web interface using the username and password. Once you are successfully logged in you can continue on with the rest of the setup. 

If you are struggling to gain access, share your router make and model in the [DigiNode Tools Telegram group](https://t.me/DigiNodeTools), and someone will try and help you.


### Step 7.2 - Assign a Static IP Address to your Pi

Open Safari, and visit [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/) and click the 'Download for macOS' button to download the 'Raspberry Pi Imager' software to your computer. 

![Download Raspberry Pi Imager for macOS](/images/macos_setup_2_1.png)


### A Brief Primer on Port Forwarding

These instructions are being worked on. Check back soon.

### Step 7.3 - Enable Port Forwarding

Open Safari, and visit [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/) and click the 'Download for macOS' button to download the 'Raspberry Pi Imager' software to your computer

![Download Raspberry Pi Imager for macOS](/images/macos_setup_2_1.png)








# NEXT: Please Donate to Support DigiNode Tools!

Did you find these instructions helpful?

I have devoted thousands of unpaid hours to create DigiNode Tools. I did this because I wanted to make it easy for anyone to run a DigiByte full node. If they helped you, please make a donation to support my work. Many thanks, Olly  >> Find me on Twitter [@saltedlolly](https://twitter.com/saltedlolly) <<

**[dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup](digibyte:dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup)**

![DigiByte Donation QR Code](/images/donation_qr_code.png)


To return to the less detailed instructions, click [here](/docs/rpi_setup.md).