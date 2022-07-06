# Build your own DigiNode

To buid your own DigiNode, you will need a Raspberry Pi 4 8Gb with power supply, SSD and case. Links for all required items are below. For the case and SSD, two options have been provided to suit different budgets. You do not need to use the exact specs provided but these should give you a starting point.

Disclaimer: This page includes affiliate links. By purchasing your equipment from here, you are helping to support development of DigiNode Tools. Thanks for your support.


## Raspberry Pi 4 Model B 8Gb
Purchase:
- [Amazon.com](https://amzn.to/3nIH6Pq)
- [Amazon.co.uk](https://amzn.to/3Rek4h6)
- [Amazon.fr](https://amzn.to/3bSHYhM)
- [Amazon.nl](https://amzn.to/3yLOKip)
- [Amazon.de](https://amzn.to/3yjVYZp)

Note: DigiByte Core requires  at least 5Gb RAM to run. For this reason, the 8Gb model Pi 4 is highly reccomended. The 4Gb model will function but requires a swap file and performance will be very sluggish. Fine for testing, but not recommended for long term use.  As of July 2022, due to the global chip shortage, Raspberry Pi's are still dificult to find and may be out of stock at the provided links. You can monitor stock availability at the [rpilocator website](https://rpilocator.com/). You can also sign up for stock alerts on [Twitter](https://twitter.com/rpilocator) or [Telegram](https://t.me/raspberry_alert_pi). Be wary of price gouging - the MSRP of the Pi4 8Gb is $75 USD. 

![Raspberry Pi 4 Model B 8Gb](/images/rpi4_8gb.jpg)

## Genuine Raspberry Pi 4 PSU
Purchase:
- [Amazon.com](https://amzn.to/3ae8To1)
- [Amazon.co.uk](https://amzn.to/3P5YtFI)
- [Amazon.de](https://amzn.to/3NH7mo5)
- [Amazon.nl](https://amzn.to/3AvtgYs)

Note: Aftermarket power supplies can be cheaper but are frequently prone to voltage issues. Since the Pi is also powering the SSD, it is highly recommnded to purchase a genuine official Raspberry Pi 4 power supply. 

![Raspberry Pi 4 PSU](/images/rpi4_psu.jpg)


# Option A: Argon One M.2 Case with internal SSD

| **Pros**                                          | **Cons**                             			     |
|---------------------------------------------------|----------------------------------------------------|
| More compact - SSD is enclosed in the Pi case  	| Not the cheapest option     			             |
| Active cooling (Fan included)                     | 		                                             |
| Better performance with an optional NVME SSD      | 		                                             |

## Argon ONE M.2 Case for Raspberry Pi 4
Purchase:
- [Amazon.co.uk](https://amzn.to/3alBS9k)

Note: There are two variants of the Argon One M.2 case - one that supports a M.2 SATA SSD (slower) and the other supports a M.2 NVME SSD (faster). Either will work but you need to buy the correct SSD to match your chosen case. (See SSD info below.). The Argon case is aluminium which helps to passively cool the Pi, and the SSD is housed within the case making the entire device nice and compact. The fan can be controlled by software to activate it at the relevant temperature threshold.
![Argon One M.2 Case](/images/argon_m2.jpg)

## M.2 SATA SSD
Purchase:
- [Amazon.co.uk](https://amzn.to/3yhYoIg)

Note: You need to choose the correct type of M.2 SSD depending on which Argon M.2 case you choose - SATA or NVME. SATA is older and slower. NVME is newer and faster. SATA is more than adequate for a DigiNode, unless you want the extra performance. More info [here](https://www.pcguide.com/ssd/guide/nvme-vs-m-2-vs-sata/). Note that M.2 NVME and M.2 SATA connectors are different - SATA connectors have one slot whereas NVME connectors have two.

![M.2 SATA SSD](/images/m2_sata_ssd.jpg)

## USB A to USB A Cable
Purchase:
- [Amazon.co.uk](https://amzn.to/3NNCfY3)

Note: Since the SSD is enclosed in the Argon One case, this cable makes it possible to connect the SSD directly to your computer to copy over the operating system image. Without it you will likely need to first boot the Raspberry Pi from a microSD card and use this to burn the image on to the SSD making the setup process longer and more complicated. This cable will save you a lot of headaches! It is optional but highly recommended. 

![USB A to USB A Cable](/images/usb_atoa_cable.jpg)


# Option B: Flirc Case with external SSD

| **Pros**              | **Cons**                             			     |
|-----------------------|----------------------------------------------------|
| Cheaper   			| Passive Cooling Only (No Fan)     				 |
|   					| Less compact (SSD is in a seperate case) 			 |

## Flirc Case for Raspberry Pi 4
Purchase:
- [Amazon.co.uk](https://amzn.to/3IjCkRV)
- [Amazon.com](https://amzn.to/3R5abSN)
- [Amazon.ca](https://amzn.to/3P1YcDA)

Note: The Flirc case is made of aluminium, and the entire case acts as a heat sync to keep your Pi cool. It does not inculde a fan. During the intial sync of the blockchain it can get quite hot, but the rest of the time is should be fine. If you choose a case without a fan make sure it has passive cooling of some kind.
![Flirc case](/images/flirc_case.jpg)

## Orico USB 3.1 10Gbps USB-C SSD Enclosure
Purchase: 
- [Amazon.com](https://amzn.to/3P4VTQh) 
- [Amazon.co.uk](https://amzn.to/3ydNfbf) 
- [Amazon.nl](https://amzn.to/3yh6Asc)

Note: You can use whichever SSD enclosure you like but try to to ensure it is at least USB 3.1 Gen 2 10Gbps. Some enclosures are only 6Gbps.

![Orico enclosure](/images/orico_enclosure.jpg)

## Crucial 2.5" SSD
Purchase:
- [Amazon.co.uk](https://amzn.to/3IjFNjF)

Note: As of July 2022, DigiNode requires ~40GB of space. You can choose any size of SSD you want that is larger than this. I recommend 250Gb or 500Gb to be more future proof.

![Crucial 2.5" SSD](/images/crucial_2.5_ssd.jpg)
