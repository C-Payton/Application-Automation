# AWR Design Environment - Cadence Design Systems (v15.04.00)

App Package for the Cadence AWR Design Environment (Microwave Office). 
This is packaged with PS APP DEPLOY toolkit for easy installation (Direct Run, SCCM/MECM Task Sequence, Software Center, Application Deployment, and Package Deployment.)

Package will remove any older version of AWR installed. Then install latest Cadence AWR Design Environment silently, configure, and setup FlexLM licensing ENV variable.   

### Dependencies
* PS APP Deploy Toolkit (PSADTK) (Built using version 3.8.4)
* Windows 10 OS
* Windows PowerShell 5.0+
* Latest AWR Design Environment (Currently v15.04 Build 10117_2) (requires a login and active Cadence AWR license)
      *( https://downloads.cadence.com/ )
* SCCM/MECM (I.e. For user self-service application install or application/package deployment)

### How to use this code

* Run Directly "  Deploy-Application.exe  " (This will install AWR Design Environment)

* Create SCCM Application or Package (Use the following for Install and Uninstall under SCCM/MECM application types)
    * Deploy-Application.exe Install
        * Installs AWR and sets licensing
    * Deploy-Application.exe Uninstall
        * Removes AWR and all leftover files.
       
 * Included Detect_App.ps1 file is for SCCM/MECM Application Deployment Script Detection Method (Checks installed version as reported in registry). 
 
## Help

NOTE: Make sure you set your FlexLM information for your AWR license server " $appLicenseInfo = 'port@license.server' ".

* Reference guide for installing AWR Design Environment can be found on Cadence Downloads portal. 

## Version History

* 1.0.0 (4/16/2022)
    * Initial Github Release 
    * PSAppDeployToolkit v3.8.4 (Jan 26, 2021)
    * AWR Design Environment v15.04.10117.2

## Registry Information 

* FullPath: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{3C31E93E-C322-4A9D-BC0D-B1B3809527CD}
* DisplayName: AWR Design Environment 15 (15.04.10117.2) 64-bit
* Publisher: Cadence Design Systems, Inc.
* DisplayVersion: 15.04.10117.2
* UninstallString: MsiExec.exe /I{3C31E93E-C322-4A9D-BC0D-B1B3809527CD}
* KeyName: {3C31E93E-C322-4A9D-BC0D-B1B3809527CD}
