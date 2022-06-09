# Python 3.x - Python Software Foundation (v3.10.5)

App Package for Python. 
This is packaged with PS APP DEPLOY toolkit for easy installation (Direct Run, SCCM/MECM Task Sequence, Software Center, Application Deployment, and Package Deployment.)

Package will remove any older version of Python 3.x installed. Then install latest Python 3.x silently, configure, and setup ENV variables.   

### Dependencies
* PS APP Deploy Toolkit (PSADTK) (Built using version 3.8.4)
* Windows 10 OS
* Windows PowerShell 5.0+
* Latest Python (Currently v3.10.5) 
		*( https://www.python.org/downloads/ )
* SCCM/MECM (I.e. For user self-service application install or application/package deployment)

### How to use this code

* Run Directly "  Deploy-Application.exe  " (This will install Python)

* Create SCCM Application or Package (Use the following for Install and Uninstall under SCCM/MECM application types)
    * Deploy-Application.exe Install
        * Installs Python
    * Deploy-Application.exe Uninstall
        * Removes Python and all leftover files.
       
 * Included Detect_App.ps1 file is for SCCM/MECM Application Deployment Script Detection Method (Checks installed version as reported in registry). 
 
## Help

NOTE: This script will remove any exiting 3.x version of Python, but not any older 2.x.

## Version History

* 1.0.0 (6/9/2022)
    * Initial Github Release 
    * PSAppDeployToolkit v3.8.4 (Jan 26, 2021)
    * Python v3.10.5
