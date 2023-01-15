# DigiNode Setup on a Raspberry Pi - Step-by-Step Instructions

IMPORTANT: If you have not already completed DigiNode Setup on your Raspberry Pi, then please go [here](/docs/rpi_setup_step6_run_diginode_setup.md) and complete STEP 6.


## STEP 7 - Give the Raspberry Pi a Static IP address and setup Port Forwarding

Setting up port forwarding is probably the trickiest part of the entire setup, simply because all routers are diferent. However, it is also probably the most important step, since it makes it possible for other nodes on the Internet to find yours. Without doing this, your node is not able to fully support the network.


### A Brief Primer on Dynamic vs Static IP Addresses

Every single device on your LAN (Local Area Network) is identified by its IP address - a string of numbers separated by periods e.g. 192.168.1.125. By default, your router's DHCP (Dynamic Host Control Protocol) server assigns a dynamic IP Address to every device that connects to the network. Each connected device can then periodically renew the lease on the IP address it has been allocated, but should it disappear from the network, the IP address is released for another device to use. This helps prevent the router from running out of IP addresses. However, this also means that a device on your network is not guaranteed to always be available at its current IP address.

IP addresses on a local network are typically in the range from 192.168.1.1 to 192.168.1.254. The router itself will usually take one of these (usually 192.168.1.1 or 192.168.1.254) and will then have DHCP allocate all or some of the remaining addresses for use by the other devices on your network.

Sometimes it can be beneficial for a device to always have the same IP address (i.e. a Static IP address) each time it connects to the network. This is very useful for servers. In the case of your DigiNode, giving it a Static IP means you will always be able to easily find it on your network, and more importantly forward internet traffic to it.

In order to assign a Static IP address to your DigiNode device, and to forward the required ports, you will need to access to your router's management area.


### Step 7.1 - Login to the web interface of your router

Built into almost every router is a web interface that can be used to manage it. (A notable exception is Apple's discontinued Airport devices that use the 'Airport Utility' app to manage them.). The IP address, username and password to access this varies depending on your router manufacturer. In most cases, there is usually a sticker on the router itself telling you how to connect to it, similar to the example below.

![Router Label](/images/router_label.jpg)

The sticker on your router, will hopefully tell you the website address (or IP address) to access the admin page, along with the username and password. If it does not include these, try googling your router make and model to find out the default username and password. (Note: The admin password is not the same as the wifi password.)

You can also try visiting http://whatsmyrouterip.com/ or https://www.routerpasswords.com/ for help finding the default login and password for your router model.

Once you have found the login credentials, enter the IP address or web address into your browser, and then login to the web interface using the username and password.

If you are struggling to gain access, share your router make and model in the [DigiNode Tools Telegram group](https://t.me/DigiNodeTools), and someone will try and help you.

Once you are successfully logged in you can continue on with the next step.


### Step 7.2 - Adjust the range of dynamic IP addresses [OPTIONAL]

If you have not already done so, it can sometimes be helpful to adjust the range of dynamic IP addresses on your router, so you have some space outside of it to assign Static IP addresses. (Note: This step is optional, but it can be helpful to keep things tidy.)

![DHCP Range](/images/dhcp_settings.png)

In the example above, IP addresses have been organised as follows:

| IP Address Range              | Devices                   |
|-------------------------------|---------------------------|
| 192.168.1.1 - 192.168.1.30 	| Static IP addresses		|
| 192.168.1.31 - 192.168.1.253	| Dynamic IP addresses		|
| 192.168.1.254   				| Router (Gateway)			|

This means that as long as Static IP addresses are kept between 1 and 30 then will never clash with any Dynamic IP addresses.

By adjusting your DHCP server range, you can safely assign a Static IP addresses outside that range, safe in the knowledge they will not clash. 


### Step 7.3 - Assign a Static IP Address to your Pi

The method for setting a Static IP address varies from router to router. The best way to know how to do it for yours is to google the make and model with the words 'assign static ip'. 

In the example below, the process involves locating the DigiNode device in the current list of active DHCP leases (the dynamic addresses) and copying its MAC address. Then, in the 'Static DHCP lease configuration' below that, enter the MAC address, along with the desired IP address for that device, and its hostname. Clicking the green '+' button will add the entry, and 'Save' will save the change. 

(Note: A Media Access Control address (MAC address) is a hardware identifier that uniquely identifies each device on a network. Primarily, the manufacturer assigns it. They are often found on a device’s network interface controller (NIC) card. A MAC address can also be referred to as a burned-in address, Ethernet hardware address, hardware address, or physical address.)

![DHCP Range](/images/dhcp_static_lease.png)

On some routers, like the 'BT HomeHub' the process differs in that you need to click on the device in the list of connected devices and then set to always use this IP. (You can manually change the IP address itself above.)

![DHCP Range](/images/dhcp_fixed_ip.jpg)

For your changes to take effect, it may be required to restart the Raspberry Pi and/or the Router particularly if the IP address of the device has been changed.

At any point, you can run 'DigiNode Status Monitor' to quickly check the current local IP address of the Raspberry Pi.

Once you have successfully, given your device a Static IP address, make a note of it since it will make it easy to access your DigiNode in future. you can then proceed to the next step.

### A Brief Primer on Port Forwarding

Port forwarding, sometimes called port mapping, allows computers or services on the public Internet to connect to a computer or service on your local private network. Your router has an external IP address on the public internet, and through port mapping, incoming requests from the internet to a specific port can be redirected to a specific local device on your network.

Your router's public IP address can be thought of like the address of an office building, with the local IP addresses representing floors in the building, and port numbers representing specific rooms on each floor. Port forwarding rules help ensure that a message arriving at the building makes its way to the correct room. In normal use, the public internet can only ever see the building, not what floors, and rooms it has available. Port forwarding lets you selectively make specific rooms available to the public internet, while keeping the rest of the building off-limits.

### Step 7.4 - Enable Port Forwarding

The DigiByte blockchain is made up of hundreds of other nodes like yours. To make it easy for these other nodes to connect to yours from the Internet, it is essential that you enable port forwarding for your DigiByte full node and/or DigiAsset Node. If you fail to do this, their ability to support the network will be severely limited.

If you setup a mainnet DigiNode, the default ports you need to forward are:
- DigiByte Core: **12024** TCP
- IPFS: **4001** TCP

If you setup a testnet DigiNode, the default ports you need to forward are:
- DigiByte Core: **12026** TCP
- IPFS: **4004** TCP

The method for opening these ports varies from router to router. Like the previous step, the best way to know how to do it for yours is to google the make and model with the words 'port forward' to find instructions specific to your router. 

You can also try visiting: https://portforward.com/router.htm (Click on the manufacturer of your router for port forwarding instructions for your specific model.)

The principle involves creating a new port forwarding rule, that will take internet traffic arriving at your router on a specific port (or ports), and redirect it on to a specific device within your network, typically on the same port(s). How the rule identifies your DigiNode device varies from router to router - it might ask you to simply select your DigiNode from a list of connected devices. It may alternatively ask for the MAC address, IP address or hostname of the DigiNode.

In the example screenshot below, it shows the two rules that have been created for the DigiNode. For 'DigiByte Core', the rule will take external traffic on the internet on port 12024 and redirect it internally to device 'diginode' also on port 12024. The rule is identifying the DigiNode by its hostname, in this instance. 

![DigiNode Port Forwarding](/images/diginode_port_forwarding.png)

If you mirror this settings of your router then they should work.


# NEXT: Please Donate to Support DigiNode Tools!

Did you find this guide helpful?

I created DigiNode Tools because I want to make it easy for anyone who wants to to run their own DigiByte and DigiAsset Node. So far, I have devoted thousands of unpaid hours working towards this goal. If this guide has helped you, please make a donation to support my work. Many thanks, Olly

PS You can find me on Twitter [@saltedlolly](https://twitter.com/saltedlolly)

**[dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup](digibyte:dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup)**

![DigiByte Donation QR Code](/images/donation_qr_code.png)


To return to the less detailed instructions, click [here](/docs/rpi_setup.md).