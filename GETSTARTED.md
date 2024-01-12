![DigiNode Tools Logo](images/diginode_tools_logo.png)

# Get Started with DigiNode Tools

Follow the instuctions below for you specific system:

## ➡️ Setup a DigiNode on Raspberry Pi 4

Go [here](docs/rpi_setup.md) for detailed step-by-step instructions on how to setup a DigiNode on a Raspberry Pi 4.

## ➡️ Setup a DigiNode on Debian / Ubuntu

IMPORTANT:

- If it is not already installed, you will need to first install 'sudo' to use DigiNode Tools on Debian.
- It is recommended to create a new user for your DigiNode called 'digibyte'. This will isolate your wallet in its own acccount.
- Run the setup script as the 'digibyte' user (not as root).

Launch DigiNode Setup by entering the following command in the terminal:

  **```curl -sSL setup.diginode.tools | bash```**

# Advanced Features

These features are for advanced users and should be used with caution:

**DigiNode Setup Help:** Use the --help flag to view all the available flags that can be used at launch:
- ```curl -sSL setup.diginode.tools | bash -s -- --help``` or
- ```diginode-setup --help```

**Unattended Mode:** This is useful for installing the script completely unattended. To run in unattended mode, use the --unattended flag at launch. 
- ```curl -sSL setup.diginode.tools | bash -s -- --unattended``` or
- ```diginode-setup --unattended```

Note: The first time you run DigiNode Setup in Unattended mode, it will create the required diginode.settings file and then exit. If you wish to customize your installation further, you can edit this file before proceeding. It is located here: ~/.digibyte/diginode.settings
If you want to skip this step, and simply use the default settings, include the --skipcustommsg flag:
- ```curl -sSL setup.diginode.tools | bash -s -- --unattended --skipcustommsg``` or
- ```diginode-setup --unattended --skipcustommsg```

**Install DigiByte Core Pre-release:** The --dgbpre flag can be used to install the pre-release version of DigiByte Core, if available: 
- ```curl -sSL setup.diginode.tools | bash -s -- --dgbpre``` or
- ```diginode-setup --dgbpre```

If you are running a pre-release version of DigiByte, and want to downgrade back to the release version use the --dgbnopre flag:
- ```curl -sSL setup.diginode.tools | bash -s -- --dgbnopre``` or
- ```diginode-setup --dgbnopre```

**DigiAsset Node ONLY Setup:** If you have a low spec device that isn't powerful enough to run DigiByte Node, you can use the ```--dganodeonly``` flag to setup only a DigiAsset Node. Using this flag bypasses the hardware checks required for the DigiByte Node. A DigiAsset Node requires very little disk space or memory and should work on very low power devices. If you later decide you want to install a DigiByte Node as well, you can use the ```--fulldiginode``` flag to upgrade your existing DigiAsset Node setup. This can also be accessed from the main menu.
- ```curl -sSL setup.diginode.tools | bash -s -- --dganodeonly``` or
- ```diginode-setup --dganodeoonly```

**Skip OS Check:** The --skiposcheck flag will skip the OS check at startup in case you are having problems with your system. Proceed with caution.
- ```curl -sSL setup.diginode.tools | bash -s -- --skiposcheck``` or
- ```diginode-setup --skiposcheck```

**Skip Package Cache Update:** The --skippkgcache flag will skip trying to update the package cache at launch in case you are do not have permission to do this. (Some VPS won't let you update.)
- ```curl -sSL setup.diginode.tools | bash -s -- --skippkgcache``` or
- ```diginode-setup --skippkgcache```

**Verbose Mode:** This provides much more detailed feedback on what the scripts are doing - useful for troubleshooting and debugging. This can be set using the ```--verboseon``` flags.
- ```curl -sSL setup.diginode.tools | bash -s -- --verboseon```
- ```diginode-setup --uninstall```

**Manually Locate DigiByte Core:** If you wish to use the DigiNode Status Monitor with your existing DigiByte Node (i.e. One not setup with DigiNode Tools), and the startup checks are not able to locate it automatically, use the ```--locatedgb``` flag at launch to manually specify the folder location.
- ```diginode --locatedgb```

**Developer Mode:** To install the development branch of DigiNode Tools, use the ```--dgntdev``` flag at launch. The ```--dgadev``` flag can be used to install the development branch of the DigiAsset Node. WARNING: These should only be used for testing, and occasionally may not run.
- ```curl -sSL setup.diginode.tools | bash -s -- --dgntdev --dgadev``` or
- ```diginode-setup --dgntdev --dgadev```

**Uninstall:** The --uninstall flag will uninstall your DigiNode. Your DigiByte wallet will be kept. This can also be accessed from the main menu.
- ```curl -sSL setup.diginode.tools | bash -s -- --uninstall``` or
- ```diginode-setup --uninstall```

**Reset Mode**: This will reset and reinstall your current installation using the default settings. It will delete digibyte.conf, diginode.settings and main.json and recreate them with default settings. It will also reinstall DigiByte Core and the DigiAsset Node. IPFS will not be re-installed. Do not run this with a custom install or it may break things. For best results, run a standard upgrade first, to ensure all software is up to date, before running a reset. Software can only be re-installed if it is most recent version. You can perform a Reset via the DigiNode Setup main menu by entering ```diginode-setup```. You can also use the --reset flag at launch.
- ```curl -sSL setup.diginode.tools | bash -s -- --reset``` or
- ```diginode-setup --reset```

# Support

If you need help, please post a message in the [DigiNode Tools Telegram group](https://t.me/DigiNodeTools). You can also reach out to [@digibytehelp](https://twitter.com/digibytehelp) on Twitter or [@diginode.tools](https://bsky.app/profile/diginode.tools) on Bluesky.

## Please DONATE to Support DigiNode Tools!

I created DigiNode Tools to make it easy for everybody to run their own DigiByte and DigiAsset Node. I have devoted thousands of unpaid hours on this goal, all for the benefit of the DigiByte community. PLEASE DONATE to help me cover server costs and support future development. You can find me on Twitter [@saltedlolly](https://twitter.com/saltedlolly) and Bluesky [@olly.st](https://bsky.app/profile/olly.st). Many thanks, Olly

**dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup**

![DigiByte Donation QR Code](images/donation_qr_code.png)
