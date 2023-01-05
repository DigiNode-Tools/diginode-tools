# Build your own DigiNode

Probably, the easiest way to build your own dedicated DigiNode is with a Raspberry Pi single-board computer. You will aso need a power supply, SSD (Solid State Drive) and case. Links for for all these items are below. For the case and SSD, two options have been provided to suit different budgets. The Argon One holds an internal SSD whih makes the entire unit compact and self-contained. Using the Flirc case makes the entire build a bit cheaper, but the SSD uses a seperate external case.

| **Option A: Argon One M.2 Case w/ Internal SSD** | **Option B: Flirc Case w/ External SSD** |
|--------------------------------------------------|------------------------------------------|
| Elegant self-contained unit with fan cooling     | Cheaper. Passively cooled. Less compact. |
|--------------------------------------------------|------------------------------------------|
| Raspberry Pi 4 8Gb 				               | Raspberry Pi 4 8Gb 				      |
| Raspberry Pi 4 Power Supply                      | Raspberry Pi 4 Power Supply              |
| Argon One M.2 SATA Case      		               | Flirc Case for Pi 4                      |
| M.2 SATA SSD - 250Gb      		               | Orico USB 3.1 10Gbps USB-C SSD Enclosure |
| USB A to USB A Cable     		                   | Crucial 2.5" SSD 250Gb	                  |
| Ethernet cable                                   | Ethernet cable                           |

Disclaimer: This page includes affiliate links. By purchasing your equipment from here, you are helping to support development of DigiNode Tools. Thanks for your support.            

## Raspberry Pi 4 Model B 8Gb
![Raspberry Pi 4 Model B 8Gb](/images/rpi4_8gb.jpg)

The Rasperry Pi 4 Model B is available in 8Gb, 4Gb, 2Gb and 1Gb models. DigiByte Core requires at least 5Gb RAM to run. For this reason, only the 8Gb model Pi 4 is recommended. The 4Gb model will run, but performance will be very sluggish, and it will require a large swap file that puts a lot of strain on the SSD. In short, 4Gb is fine for testing, but definitely not recommended for long term use. The 2Gb and 1Gb Pi 4 models are definitely not supported.

As of December 2022, due to the global chip shortage, the Raspberry Pi 4 is still experiencing stock shortages, and may currently be unavailable at the provided links. You can monitor global stock availability at the [rpilocator website](https://rpilocator.com/). You can also sign up for stock alerts on [Twitter](https://twitter.com/rpilocator) or [Telegram](https://t.me/raspberry_alert_pi). 

**Be wary of price gouging - the MSRP of the Pi4 8Gb is $75 USD.**

Purchase:
- [Amazon.com](https://amzn.to/3nIH6Pq)
- [Amazon.com.au](https://amzn.to/3Rg1hSh)
- [Amazon.ca](https://amzn.to/3IkogHN)
- [Amazon.co.uk](https://amzn.to/3Rek4h6)
- [Amazon.de](https://amzn.to/3yjVYZp)
- [Amazon.es](https://amzn.to/3P9D9Po)
- [Amazon.fr](https://amzn.to/3bSHYhM)
- [Amazon.it](https://amzn.to/3ReCXQV)
- [Amazon.nl](https://amzn.to/3yLOKip)
- [Amazon.se](https://amzn.to/3yMiifO)
- [Amazon.sg](https://amzn.to/3yoOcxl)

## Genuine Raspberry Pi 4 Power Supply
![Raspberry Pi 4 Power Supplies](/images/rpi4_psu.jpg)

Third party power supplies can be cheaper but are frequently prone to voltage issues. Since the Pi is also powering the SSD, it is highly recommnded to purchase a genuine official Raspberry Pi 4 power supply. 

Purchase:
- [Amazon.com](https://amzn.to/3ae8To1)
- [Amazon.com.au](https://amzn.to/3uwjpO9)
- [Amazon.ca](https://amzn.to/3IiHkGq)
- [Amazon.co.uk](https://amzn.to/3P5YtFI)
- [Amazon.de](https://amzn.to/3NH7mo5)
- [Amazon.es](https://amzn.to/3usJr4I)
- [Amazon.fr](https://amzn.to/3PcbRbs)
- [Amazon.it](https://amzn.to/3OQk6Ka)
- [Amazon.nl](https://amzn.to/3AvtgYs)
- [Amazon.se](https://amzn.to/3NRs18O)
- [Amazon.sg](https://amzn.to/3OSHyqu)


# Option A: Argon One M.2 Case with internal SSD

| **Pros**                                          | **Cons**                             			     |
|---------------------------------------------------|----------------------------------------------------|
| More compact - SSD is enclosed in the Pi case  	| Not the cheapest option     			             |
| Active cooling (Fan included)                     | 		                                             |
| Better performance with an optional NVME SSD      | 		                                             |

## Argon ONE M.2 Case for Raspberry Pi 4 (SATA SSD Model)
![Argon One M.2 Case](/images/argon_m2.jpg)

The Argon One case is aluminium which helps to passively cool the Pi, and the SSD is housed within the case making the entire device nice and compact. The fan can be controlled by software to activate it at the desired temperature threshold.

Note that there are two variants of the Argon One M.2 Case - one that supports a M.2 SATA SSD (slower) and the other supports a M.2 NVME SSD (faster). Either is suitable but you need to buy the correct SSD to match your chosen case. (See SSD info below.). These links below are for the SATA case.

Purchase:
- [Amazon.com](https://amzn.to/3nHfRVB)
- [Amazon.com.au](https://amzn.to/3yK5dni)
- [Amazon.ca](https://amzn.to/3Ii1twm)
- [Amazon.co.uk](https://amzn.to/3alBS9k)
- [Amazon.de](https://amzn.to/3OQHlUu)
- [Amazon.es](https://amzn.to/3NPzaqn)
- [Amazon.fr](https://amzn.to/3NPzaqn)
- [Amazon.it](https://amzn.to/3OZnBOi)
- [Amazon.nl](https://amzn.to/3InbgBy)
- [Amazon.se](https://amzn.to/3O2nNeV)
- [Amazon.sg](https://amzn.to/3P35yGM)

## M.2 SATA SSD
![M.2 SATA SSD](/images/m2_sata_ssd.jpg)

Depending on which Argon M.2 case you choose, you need to choose the correct type of M.2 SSD - SATA or NVME. NVME is newer technology and faster, but SATA is more than adequate for a DigiNode, unless you want the extra performance. Note that M.2 NVME and M.2 SATA connectors are different - SATA connectors have two gaps whereas NVME connectors have one. Learn more about the diference between NVME and SATA [here](https://www.pcguide.com/ssd/guide/nvme-vs-m-2-vs-sata/). The links below are for a SATA SSD.

As of December 2022, a DigiNode requires approximately 44GB of space. You can choose any size of SSD you want that is larger than this. A 250Gb SSD would be an excellent choice, or 500Gb to be more future proof.

Purchase:
- [Amazon.com](https://amzn.to/3OZoVAK)
- [Amazon.com.au](https://amzn.to/3Ax4FSV)
- [Amazon.ca](https://amzn.to/3RisRhK)
- [Amazon.co.uk](https://amzn.to/3yhYoIg)
- [Amazon.de](https://amzn.to/3IjrQls)
- [Amazon.es](https://amzn.to/3bXVRLO)
- [Amazon.fr](https://amzn.to/3urgbeY)
- [Amazon.it](https://amzn.to/3PdSIpz)
- [Amazon.nl](https://amzn.to/3nIZDv3)
- [Amazon.se](https://amzn.to/3Ax55bX)
- [Amazon.sg](https://amzn.to/3RsBruL)

## USB A to USB A Cable
![USB A to USB A Cable](/images/usb_atoa_cable.jpg)

Since the SSD is enclosed in the Argon One case, this cable makes it possible to connect the SSD directly to your computer to copy over the operating system image. Without it you will likely need to first boot the Raspberry Pi from Raspberry Pi OS a microSD card and then burn the image on to the SSD from that making the setup process longer and more complicated. This cable makes the setup process much simpler, and avoids unnecesary headaches! It is optional but highly recommended. 

Purchase:
- [Amazon.com](https://amzn.to/3ON6jV1)
- [Amazon.com.au](https://amzn.to/3AuqEtK)
- [Amazon.ca](https://amzn.to/3NMdoUs)
- [Amazon.co.uk](https://amzn.to/3NNCfY3)
- [Amazon.de](https://amzn.to/3OQDKFY)
- [Amazon.es](https://amzn.to/3AuCGDk)
- [Amazon.fr](https://amzn.to/3uw2qvj)
- [Amazon.it](https://amzn.to/3ym7rrv)
- [Amazon.nl](https://amzn.to/3nHppzF)
- [Amazon.se](https://amzn.to/3yjpeQ9)
- [Amazon.sg](https://amzn.to/3bVpuxg)

# Option B: Flirc Case with external SSD

| **Pros**              | **Cons**                             			     |
|-----------------------|----------------------------------------------------|
| Cheaper   			| Passive Cooling Only (No Fan)     				 |
|   					| Less compact (SSD is in a seperate case) 			 |

## Flirc Case for Raspberry Pi 4
![Flirc case](/images/flirc_case.jpg)

This Flirc case is made of aluminium, and the entire case acts as a heat sync to keep your Pi cool. It does not inculde a fan. During the intial sync of the blockchain it can get quite hot, but the rest of the time is should be fine. If you choose a case without a fan make sure it has passive cooling of some kind.

Purchase:
- [Amazon.com](https://amzn.to/3R5abSN)
- [Amazon.com.au](https://amzn.to/3aj6YhV)
- [Amazon.ca](https://amzn.to/3P1YcDA)
- [Amazon.co.uk](https://amzn.to/3IjCkRV)
- [Amazon.de](https://amzn.to/3akPeCI)
- [Amazon.es](https://amzn.to/3yLi0Ws)
- [Amazon.fr](https://amzn.to/3RhDGkc)
- [Amazon.it](https://amzn.to/3ONDDer)
- [Amazon.nl](https://amzn.to/3yK92sE)
- [Amazon.se](https://amzn.to/3yM9cj3)
- [Amazon.sg](https://amzn.to/3Infnxu)

## Orico USB 3.1 10Gbps USB-C SSD Enclosure
![Orico enclosure](/images/orico_enclosure.jpg)

You can use whichever SSD enclosure you like but try to to ensure it is at least USB 3.1 Gen 2 10Gbps. Some enclosures are only Gen 1 6Gbps.

Purchase: 
- [Amazon.com](https://amzn.to/3P4VTQh) 
- [Amazon.com.au](https://amzn.to/3uv51FY)
- [Amazon.ca](https://amzn.to/3O2tlGh)
- [Amazon.co.uk](https://amzn.to/3ydNfbf) 
- [Amazon.de](https://amzn.to/3nKdz7X)
- [Amazon.es](https://amzn.to/3Rg5Gon)
- [Amazon.fr](https://amzn.to/3arL1wW)
- [Amazon.it](https://amzn.to/3uuu4ZI)
- [Amazon.nl](https://amzn.to/3yh6Asc)
- [Amazon.se](https://amzn.to/3Aydax8)
- [Amazon.sg](https://amzn.to/3ImPptC)

## Crucial 2.5" SSD
![Crucial 2.5" SSD](/images/crucial_2.5_ssd.jpg)

As of December 2022, DigiNode requires approximately 45GB of space. You can choose any size of SSD you want that is larger than this. A 250Gb SSD would be an excellent choice, or 500Gb to be more future proof.

Purchase:
- [Amazon.com](https://amzn.to/3ORS4hq)
- [Amazon.com.au](https://amzn.to/3RcdHe2)
- [Amazon.ca](https://amzn.to/3NPTc3M)
- [Amazon.co.uk](https://amzn.to/3IjFNjF)
- [Amazon.de](https://amzn.to/3P1yfEo)
- [Amazon.es](https://amzn.to/3yeSMy8)
- [Amazon.fr](https://amzn.to/3uRZdXp)
- [Amazon.it](https://amzn.to/3ImFrbH)
- [Amazon.nl](https://amzn.to/3NT3Bvz)
- [Amazon.se](https://amzn.to/3ImFHaF)
- [Amazon.sg](https://amzn.to/3Irgc8j)
