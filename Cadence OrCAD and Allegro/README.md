# Cadence OrCAD and Allegro (SPB174) 17.4 - w/ patch (v17.40.028)
 
App Package for Cadence OrCAD/Allegro, a suite of products for PCB Design and analysis.
This is packaged with PS APP DEPLOY toolkit for easy silent installation (Direct Run, SCCM/MECM Task Sequence, Software Center, Application Deployment, and Package Deployment.)

Package will remove any older version of Cadence OrCAD/Allegro installed. Then install latest silently, configure, and setup client licensing.   

### Dependencies
* PS APP Deploy Toolkit (PSADTK) (Built using version 3.8.4)
* Windows 10 OS
* Windows PowerShell 5.0+
* Latest Cadence OrCAD/Allegro (Currently v17.40.028) (requires a login and active Cadence license)
* SCCM/MECM (I.e. For user self-service application install or application/package deployment)

### Setup Steps

* Download OrCAD/Allegro installer files from Cadence Downloads website (https://downloads.cadence.com/)
*	Create and pack all installer files in a VHXD file archive.
    * This reduces Download times, and requires no unpacking (can install directly through mounted VHDX) 
* Modify new version silentinstall-SPB.ini and silentinstallHotfix-SPB.ini and place under SupportFiles (use existing as template)

### How to use this code

* Run Directly "  Deploy-Application.exe  " (This will install Cadence OrCAD/Allegro)

* Create SCCM Application or Package (Use the following for Install and Uninstall under SCCM/MECM application types)
    * Deploy-Application.exe Install
        * Removes old versions and Installs latest
    * Deploy-Application.exe Uninstall
        * Uninstalls and removes all leftover files.
       
 * Included Detect_App.ps1 file is for SCCM/MECM Application Deployment Script Detection Method (Checks installed version as reported in registry). 
 
## Help

* Make sure you set your FlexLM information for your Cadence license server " $appLicenseInfo = 'port@license.server' ".
* NOTE: Cadence OrCAD/Allegro installer has issues running as SYSTEM account via MECM Task Sequence. 
    * Instead of using Application method, deploy as a Package run step as a Administrator user account (Instead of letting MECM use SYSTEM user). 

## Version History

* 1.0.0 (4/18/2022)
    * Initial Github Release 
    * PSAppDeployToolkit v3.8.4 (Jan 26, 2021)
    * OrCAD and Allegro (SPB174) v17.40.028
