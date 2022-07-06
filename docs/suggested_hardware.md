# Suggested DigiNode Hardware

To buid your own DigiNode, I reccomend a Rasperry Pi 4 8Gb with a power supply, SSD and case. Links for all the items you require are provided below. For the case and SSD, I have provided two options to suit different budgets.

Disclaimer: This page includes some affiliate links. By purchasing your equipment from here, you are helping to support future development of DigiNode Tools. Thanks for your support.


## Raspberry Pi 4 Model B 8Gb
Purchase:
- [Amazon.co.uk](https://amzn.to/3Rek4h6)

Note: Running DigiByte Core requires ~5Gb RAM. For this reason, an 8Gb Pi is strongly reccomemned. A 4Gb Pi will work but it will require a swap file, and performance will be very sluggish. For this reason, a 4Gb Pi is fine for testing, but for long term use, an 8Gb (or greater) Pi is highly recommeded. As of July 2022, Raspberry Pi's are still very hard to get hold of thanks to the global chip shortage, and they may be out of stock at the provided links. You can monitor current stock availability at the [rpilocator website](https://rpilocator.com/). You can also sign up for stock alerts on [Twitter](https://twitter.com/rpilocator) or [Telegram](https://t.me/raspberry_alert_pi).
![Raspberry Pi 4 Model B 8Gb](/images/rpi4_8gb.jpg)

## Genuine Raspberry Pi 4 PSU
Purchase:
- [Amazon.co.uk](https://amzn.to/3P5YtFI)
- [Amazon.com](https://amzn.to/3ae8To1)

Note: Aftermarket power supplies can be cheaper but are frequently prone to voltage issues. Since the Pi is also powering the SSD, it is highly recommnded to purchase a genuine official Raspberry Pi 4 power supply. 
![Raspberry Pi 4 PSU](/images/rpi4_psu.jpg)


# Option A: Argon One M.2 Case with enclosed SSD (Reccomended)

| **Pros**                                          | **Cons**                             			     |
|---------------------------------------------------|----------------------------------------------------|
| More compact - SSD is enclosed in the Pi case  	| Not the cheapest option     			             |
| Active cooling (Fan included)                     | 		                                             |
| Better performance with an NVME SSD               | 		                                             |

## Argon ONE M.2 Case for Raspberry Pi 4
Purchase:
- [Amazon.co.uk](https://amzn.to/3alBS9k)

Note: There are two variants of the Argon One M.2 case - one that supports a M.2 SATA SSD (slower) and the other supports a M.2 NVME SSD (faster). Either will work but you need to buy the correct SSD to match your chosen case. (See below.)

## M.2 SSD
Purchase:
- [Amazon.co.uk](https://amzn.to/3P5rlxz)

Note: You need to choose the correct type of M.2 SSD depending on which type your case supports - SATA or NVME. SATA is older and slower. NVME is newer and faster. SATA is more than adequate for a DigiNode, unless you want the extra performance. More info [here](https://www.pcguide.com/ssd/guide/nvme-vs-m-2-vs-sata/).

## USB A to USB A Cable
Purchase:
- [Amazon.co.uk](https://amzn.to/3NNCfY3)

Note: Since the SSD is enclosed in the Argon One case, this cable makes it possible to connect the SSD directly to your computer to copy over the operating system image. Without it you will likely need to first boot the Raspberry Pi from a microSD card and use this to burn the image on to the SSD making the process longer and more complicated. This cable will save you a lot of headaches! It is optional but highly recommended. 
![USB A to USB A Cable](/images/usb_atoa_cable.jpg)


# Option B: Flirc Case with separate SSD (Budget Friendly)

| **Pros**              | **Cons**                             			     |
|-----------------------|----------------------------------------------------|
| Cheaper   			| Passive Cooling Only (No Fan)     				 |
|   					| Less compact (SSD is in a seperate case) 			 |

## Flirc Case for Raspberry Pi 4
Purchase:
- [Amazon.co.uk](https://amzn.to/3IjCkRV)
- [Amazon.com](https://amzn.to/3R5abSN)
- [Amazon.ca](https://amzn.to/3P1YcDA)

Note: The Flirc case is made of aluminium, and the entire case acts as a heat sync to keep your Pi cool. It does not inculde a fan. During the intial sync of the blockchain it can get quite hot, but the rest of the time is should be fine. If you choose a case without fan make sure it has passive cooling of some kind.
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

Note: As of July 2022, DigiNode requires ~40GB of space. You can choose any size of SSD you want that is larger than this. I recomend 250Gb or 500Gb to be future proof.
![Crucial 2.5" SSD](/images/crucial_2.5_ssd.jpg)
