# MATLAB R2022a - MathWorks (v9.12)

App Package for MATLAB programming and numeric computing platform. 
This is packaged with PS APP DEPLOY toolkit for easy installation (Direct Run, SCCM/MECM Task Sequence, Software Center, Application Deployment, and Package Deployment.)

Package will remove any older version of MATLAB installed. Then install latest MATLAB silently, configure, and setup client licensing.   

### Dependencies
* PS APP Deploy Toolkit (PSADTK) (Built using version 3.8.4)
* Windows 10 OS
* Windows PowerShell 5.0+
* Latest MATLAB (Currently R2022a v9.12) (requires a login and active MATLAB license)
* SCCM/MECM (I.e. For user self-service application install or application/package deployment)

### Setup Steps

* Download MATLAB installer files from MATLAB website
*	Create and pack all Matlab installer files in a VHXD file archive.
    * This reduces Download times, and requires no unpacking (can install directly through mounted VHDX) 
* Modify new version activate.ini and installer_input.txt and place under SupportFiles (use existing as template)
    * Get fileInstallationKey for your site (unique to each version).
    * Get activationKey for your site.
    * Get the latest license.dat for your site (Matlab needs this file during install process).

### How to use this code

* Run Directly "  Deploy-Application.exe  " (This will install MATLAB)

* Create SCCM Application or Package (Use the following for Install and Uninstall under SCCM/MECM application types)
    * Deploy-Application.exe Install
        * Removes old versions of MATLAB and Installs latest MATLAB
    * Deploy-Application.exe Uninstall
        * Removes MATLAB and all leftover files.
       
 * Included Detect_App.ps1 file is for SCCM/MECM Application Deployment Script Detection Method (Checks installed version as reported in registry). 
 
## Help

* NOTE: Make sure you set your FlexLM information for your MATLAB license server " $appLicenseInfo = 'port@license.server' ".
* Also verify fileInstallationKey and activationKey are set in the activate.ini / installer_input.txt files.

## Version History

* 1.0.0 (4/16/2022)
    * Initial Github Release 
    * PSAppDeployToolkit v3.8.4 (Jan 26, 2021)
    * MATLAB R2022a v9.12
