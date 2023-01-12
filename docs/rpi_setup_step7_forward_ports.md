# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not already completed DigiNode Setup on your Raspberry Pi, then please go [here](/docs/rpi_setup_step6_run_diginode_setup.md) and complete STEP 6.


## STEP 7 - Give your DigiNode a static IP address, and setup port forwarding

Setting up port forwarding is probably the trickiest part of the entire process, but also the most important, since it makes it possible for other nodes on the Internet to discover yours. Without doing this, your node is not able to fully support the network.


### A Brief Primer on Dynamic vs Static IP Addresses

Every single device on your network is identified by its IP address. By default, your router's Dynamic Host Control Protocol (DHCP) server assigns a dynamic IP Address to every device that connects to the network. Each connected device can then renew the lease on the IP address it has been given, but if it disappears from the network, the IP address is released for another device to use. This ensures that previously used IP addresses are released whenever a network device stops using them. However, this also means that a device on your network is not guaranteed to always be available at its current IP address.

IP addresses on a local network are typically in the range from 192.168.1.1 to 192.168.1.254. The router itself will usually take one of these (usually 192.168.1.1 or 192.168.1.254) and will then have DHCP allocate all or some of the remaining addresses for use by the other devices on your network.

Sometimes it can be benficial for a device to always have the same IP address (i.e. a Static IP address) when it connects to the network. This is very useful for servers etc. In the case of your DigiNode, giving it a fixed IP means you will always be able to easily find it on your network, and more importantly forward internet traffic to it.

In order to assign a static IP address to your DigiNode device, and to forward the required ports, you will need to gain access to your router's management interface.


### Step 7.1 - Login to the web interface of your router

Built into almost all routers is a web interface that can be used to manage it. (A notable exception is Apple's discontinued Airport devices that use the 'Airport Utility' app to manage them.). The IP address, username and password to access this varies depending on your router manufacturer. In most cases, there is usually a sticker on the router itself telling you how to connect to it, similar to the example below.

![Router Label](/images/router_label.jpg)

The sticker on your router, will hopefully tell you the website address (or IP address) to access the admin page, along with the username and password. If it does not include these, try googling your router make and model to find out the default username and password.

You can also try visiting: http://whatsmyrouterip.com/

Once you have found the login credentials, enter the IP address or web address into your browser, and then login to the web interface using the username and password. Once you are successfully logged in you can continue on with the rest of the setup. 

If you are struggling to gain access, share your router make and model in the [DigiNode Tools Telegram group](https://t.me/DigiNodeTools), and someone will try and help you.

Now that you are logged into your router's web interface you can now proceed with the giving your DigiNode a Static IP address and setting up port forwarding.


### Step 7.2 - Adjust the range of dynamic IP addresses [OPTIONAL]

If you have not already done so, it can sometimes be helpful to adjust the range of dynamic IP addresses on your router, so you have some space outside of it to assign Static IP addresses. (Note: Sometimes, this step is unnecessary, but it can be helpful to keep things tidy.)

![DHCP Range](/images/dhcp_settings.png)

In the example above, IP addresses have been organised as follows:

- 192.168.1.1 - 192.168.1.30 		Static IP addresses
- 192.168.1.31 - 192.168.1.253	Dynamic IP addresses
- 192.168.1.254   				Router (Gateway)

This means that as long as Static IP addresses are kept between 1 and 30 then will never clash with any Dynamic IP addresses.

By adjusting your DHCP server range, you can safely assign a Static IP addresses outside that range, safe in the knowledge they will not clash. 


### Step 7.3 - Assign a Static IP Address to your Pi

The method for setting a Static IP address varies from router to router. The best way to know how to do it for yours is to google the make and model with the words 'assign static ip'. 

![DHCP Range](/images/dhcp_static_lease.png)

In the example above, the process involves locating the DigiNode device in the current list of active DHCP leases (the dynamic addresses) and copying its MAC address. Then, in the 'Static DHCP lease configuration' below

Note: A Media Access Control address (MAC address) is a hardware identifier that uniquely identifies each device on a network. Primarily, the manufacturer assigns it. They are often found on a device’s network interface controller (NIC) card. A MAC address can also be referred to as a burned-in address, Ethernet hardware address, hardware address, or physical address.


### A Brief Primer on Port Forwarding

These instructions are being worked on. Check back soon.



### Step 7.3 - Enable Port Forwarding

These instructions are being worked on. Check back soon.



# NEXT: Please Donate to Support DigiNode Tools!

Did you find these instructions helpful?

I have devoted thousands of unpaid hours to create DigiNode Tools. I did this because I wanted to make it easy for anyone to run a DigiByte full node. If they helped you, please make a donation to support my work. Many thanks, Olly  >> Find me on Twitter [@saltedlolly](https://twitter.com/saltedlolly) <<

**[dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup](digibyte:dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup)**

![DigiByte Donation QR Code](/images/donation_qr_code.png)


To return to the less detailed instructions, click [here](/docs/rpi_setup.md).