# Dell Command | Update - SCCM / MECM Deploy

The Dell Command | Update (DCU) toolkit is an application for updating BIOS, firmware, driver, and Dell application updates. 
The toolkit automatically checks Dell model and applies only drives applicable to the device. 
This is packaged with PS APP DEPLOY toolkit for easy installation (SCCM/MECM Task Sequence, Software Center, Application Deployment, and Package Deployment.)

This will use the DCU command line to scan the computer, check for updates using Dell's servers, and installs drivers applicable to the device.  

## Some use cases:
* Allows users to install the latest Dell drivers outside of regular driver patching window (when deployed via Software Center). 
* Allows Administrators to rapidly deploy BIOS, firmware, driver, and Dell application updates when dealing with multiple Dell models.
* Push drivers out using SCCM/MECM and not having to maintain driver update/patch repositories for all models.

### Dependencies
* PS APP Deploy Toolkit (PSADTK)
* Dell Computer (Models OptiPlex, Latitude, Venue, XPS, Precision)
* Latest Dell Command | Update (Using Windows 32 and 64bit version for Microsoft Windows 8.1 and 10) (Not the UWP version)
      * https://www.dell.com/support/kbdoc/en-us/000177325/dell-command-update
* SCCM/MECM (I.e. For user self-service application install or for application/package deployment)

### How to use this code
* Run Directly "  Deploy-Application.exe  " (This will install DCU, scan and install all types of avaliable updates)
* Create SCCM Application or Package (You can use the following flags to install specific types of BIOS, Driver, etc.)
    * Deploy-Application.exe
        (Installs/Updates DCU and applies all types of avaliable updates)
       
    * Deploy-Application.exe -UpdateType Bios 
        (Installs/Updates DCU and only applies avaliable BIOS updates)
        
    * Deploy-Application.exe -UpdateType Display
        (Installs/Updates DCU and only applies avaliable Video Driver updates)
        
    * Deploy-Application.exe -UpdateType Network
        (Installs/Updates DCU and only applies avaliable Network Driver updates)
       
    * Deploy-Application.exe -UpdateType Drivers
        (Installs/Updates DCU and only applies avaliable Driver updates) (I.e. doesn't install BIOS and/or Firmware updates)

 * Included Detect_App.ps1 file is for SCCM/MECM Application Deployment Script Detection Method (Checks installed DCU version and Driver Update log). 
 
## Help

NOTE: If you have a BIOS Password, make sure you set the " -biosPassword=`"SecretPassword`" flag with your password.

## Version History

* 1.0.0
    * Initial Release
