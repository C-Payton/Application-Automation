<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Python Software Foundation'
	[string]$appName = 'Python'
	[string]$appRegName = 'python'
	[string]$appVersion = '3.10.5'
	[string]$appMajorVersion = '3.10'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.1.0'
	[string]$appScriptDate = '6/9/2022'
	[string]$appScriptAuthor = 'Payton Climer'
	[string]$appFile32 = 'python-3.10.5.exe'
	[string]$appFile64 = 'python-3.10.5-amd64.exe'
	[string]$appFolder = 'Python310'
	[string]$appPipModules = "scikit-learn matplotlib numpy pandas keras scipy pillow pyqtgraph pyserial pyqt5 pycryptodomex"
	[string]$appUpdateFile = ''
	[array]$appOldVersions = @()
	[array]$appIcons = @()
	[string]$appRuns = "Python"
	##*===============================================
	
	##*===============================================
	##* Update ChangeLog
	##*===============================================
	##
	## Version 1.0.0 (6/6/2022)
	##		- Branched from main Python 3.9 code
	##		- Using AppDeployToolkit version 3.8.4
	##		- Using Python 3.10.5
	##		- Major changes to Pre-Install and Uninstall code 
	##			- Added code for uninstall using Python exe installers (downloads from python website)
	##
	## Version 1.1.0 (6/9/2022)
	##		- Added check for versions of Python older than 3.5.0
	##			- 3.5 and Older used MSI installer.
	##		- Added uninstall code for handling Python release candidates
	##		- Code cleanup
	##			- reduced app variables where applicable 
	##		- Bug Fix
	##			- Added [version] type to $appDisplayVersion (Ensures that -ge check is working correctly)
	##
	##		- WARNING PSAPPDEPLOY CHANGES:
	##			- When runnng Execute-Process commands their is new handling of exit codes
	##			- I.e. ignore error 1 ( Execute-Process -Path "" -Parameters "" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '1' )
	##			- I.e. ignore any error ( Execute-Process -Path "" -Parameters "" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*' )
	##			- Read the release notes for more info ( https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/releases ) 
	##			- Also includes a Pre-Install catch for old 32bit OS machines (Remove if adding support for 32bit in code)
	##	
	##*===============================================
	
	##*===============================================
	##* Installer Notes
	##*===============================================
	##	Software uses a self extracting wrapper (which ultimately installs an MSI)
	##
	##	Download latest version from python website ( https://www.python.org/downloads/ )
	##
	##	Silent installer flag uses the following
	##		- python-x.x.x-amd64.exe /quiet InstallAllUsers=1 PrependPath=1
	##
	##	Silent uninstall flag uses the following
	##		- Uninstall using MSI method
	##		- Then using the new install exe as an uninstaller
	##
	##*===============================================
	
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps "$appRuns" -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>

		# Check if running 32bit OS and EXIT if True (This package doesn't support 32bit OS)
		if ($psArchitecture -eq "x86") {
			Show-InstallationPrompt -Message "ERROR: This APP Package Does Not Include 32bit OS Support... Please Contact CENG IT Support About a Computer Upgrade...." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}
		
		Show-InstallationProgress "Searching For Old $appName Installation....  Please Wait..."
		
		#<Pre-Installation Code here>
		
		# Search registery for any Python 3.* product
		$discoveredApps = Get-InstalledApplication -Name "$appName 3"
		
		# Grab the version numbers from the DisplayName, and  DisplayVersion / ProductCode (for really old Python 3)
		ForEach ($discoveredApp in $discoveredApps){
			$appDisplayName = $discoveredApp.DisplayName
			[version]$appDisplayVersion = $discoveredApp.DisplayVersion
			$appProductCode = $discoveredApp.ProductCode
			
			#Make sure we don't grab Anaconda 
			If (!($appDisplayName -like "*Anaconda*")){ 	
			
				#Check for really old Python 3.x Install (I.e. pre 3.5.0 , as these older versions used a MSI installer)
				If ($appDisplayVersion -ge "3.5.0"){
				
					#Extract the version from DisplayName					
					$appVersionFound = (Select-String -InputObject $appDisplayName -Pattern "(\d+(\.\w+){1,3})" -AllMatches).Matches
			
					#Add to an array of just found versions
					$appOldVersions += $appVersionFound
				}
				Else{
					#If older version, run the MSI uninstaller
					Show-InstallationProgress "Found Older MSI Python Install ($appDisplayVersion)... Removing, Please Wait..."					
					Execute-MSI -Action 'Uninstall' -Path "$appProductCode" -IgnoreExitCodes '*'
				}
			}	
		}
		
		#Sort the Array and remove duplicates
		$appOldVersions | Sort-Object
		$appOldVersions = $appOldVersions | Select-Object -Unique

		#Create temp folder
		New-Folder -Path "$envSystemDrive\temp\$appName"

		#Download the installers directly from Python (for the version/s found)
		ForEach ($appOldVersion in $appOldVersions){
			
			#This is for catching cases where a Python release canidate was installed. (I.E. Installers are called 3.5.2rc1.exe but fall under the 3.5.2 folder on the Python website)
			$TrimVersionFound = (Select-String -InputObject $appOldVersion -Pattern "(\d+(\.\d+){1,3})" -AllMatches).Matches
			
			Show-InstallationProgress "Found Python Version: $appOldVersion (Downloading Uninstaller python-$appOldVersion)"
			Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$TrimVersionFound/python-$appOldVersion.exe" -OutFile "$envSystemDrive\temp\$appName\python-$appOldVersion.exe"

			Show-InstallationProgress "Found Python Version: $appOldVersion (Downloading Uninstaller python-$appOldVersion-amd64)"
			Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$TrimVersionFound/python-$appOldVersion-amd64.exe" -OutFile "$envSystemDrive\temp\$appName\python-$appOldVersion-amd64.exe"
		
			#Run the uninstall process 
			If (Test-Path "$envSystemDrive\temp\$appName\python-$appOldVersion.exe"){
				Show-InstallationProgress "Uninstalling Old Python Install ($appOldVersion)... Please Wait..."
				Execute-Process -Path "$envSystemDrive\temp\$appName\python-$appOldVersion.exe" -Parameters '/uninstall /quiet' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				#Wait for uninstaller to close
				Start-sleep -s 5
			}	

			If (Test-Path "$envSystemDrive\temp\$appName\python-$appOldVersion-amd64.exe"){
				Show-InstallationProgress "Uninstalling Old Python Install ($appOldVersion-amd64)... Please Wait..."
				Execute-Process -Path "$envSystemDrive\temp\$appName\python-$appOldVersion-amd64.exe" -Parameters '/uninstall /quiet' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				#Wait for uninstaller to close
				Start-sleep -s 5
			}	
		}	

		If (Get-InstalledApplication -Name "Python Launcher"){
			Show-InstallationProgress "Uninstalling Old Python Launcher... Please Wait..."
			Remove-MSIApplications -Name "Python Launcher"
		}	
		
		# Remove Leftover ProgramFiles Folders
		$appOLD32Installs = Get-ChildItem "$envProgramFiles\Python3*"
		ForEach ($appOLD32Install in $appOLD32Installs) {
			$removing1 = "" + $appOLD32Install
			# if statement to check if variable is null
			If ($removing1 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Folders....  Please Wait..."
				Remove-Folder -Path "$removing1" -ContinueOnError $true
			}
		}	
		
		# Remove Leftover ProgramFiles Folders
		$appOLD64Installs = Get-ChildItem "$envProgramFilesX86\Python3*"
		ForEach ($appOLD64Install in $appOLD64Installs) {
			$removing2 = "" + $appOLD64Install
			# if statement to check if variable is null
			If ($removing2 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Folders....  Please Wait..."
				Remove-Folder -Path "$removing2" -ContinueOnError $true
			}
		}	
		
		# Remove StartMenu Shortcuts
		$appOldStartMenus = Get-ChildItem "$envCommonStartMenuPrograms\Python 3*"
		ForEach ($appOldStartMenu in $appOldStartMenus) {
			$removing = "" + $appOldStartMenu
			# if statement to check if variable is null
			If ($removing | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Shortcuts....  Please Wait..."
				Remove-Folder -Path "$removing" -ContinueOnError $true
			}
		}	
		
		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$appOldLabShorts = Get-ChildItem "$envCommonDesktop\Programs\Python 3*"
		ForEach ($appOldLabShort in $appOldLabShorts) {
			$removing3 = "" + $appOldLabShort
			# if statement to check if variable is null
			If ($removing3 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Shortcuts....  Please Wait..."
				Remove-Folder -Path "$removing3" -ContinueOnError $true
			}
		}	
		
		# Remove any leftover registry leftovers 
		Show-InstallationProgress "Checking for old Registry Entries...  Please Wait..."
		Remove-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore\3*" -Recurse
		Remove-Item -Path "HKLM:\SOFTWARE\Python\PythonCore\3*" -Recurse

		# Remove old ENV key
		Remove-RegistryKey -Key  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "PYTHONPATH" -ContinueOnError $true

		# Check the PATH variable and remove any Python stuff 
		$HKLMoldRegistry = Get-RegistryKey -Key "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "Path"
		$HKLMoldRegistry = "" + "$HKLMoldRegistry"
		
		Write-Log -Message "Here is old Reg:   $HKLMoldRegistry"
		
		# Check if there is a possible existing value in PATH 
		If ($HKLMoldRegistry -like '*Python3*'){
		
			Show-InstallationProgress "Preexisting $appName Environment Variable Detected... Please Wait..."
			
			# Split the PATH environment variable and store it in an array
			$HKLMoldRegistryArray = $HKLMoldRegistry.Split(';')
			
			# Go through the array and pull any value that maches the java jdk (loop for any multiple entries)
			ForEach ($HKLMoldRegistryArrayValue in $HKLMoldRegistryArray){
				If ($HKLMoldRegistryArrayValue -like '*Python3*'){
					$HKLMoldPATHvalue = $HKLMoldRegistryArrayValue
					
					Show-InstallationProgress "Preexisting $appName Environment Variable : $HKLMoldPATHvalue ..."
					
					# This will split the PATH environment variable and remove the JDK value found then rejoin the array into a string
					$HKLMoldRegistry = ($HKLMoldRegistry.Split(';') | Where-Object { $_ -ne "$HKLMoldPATHvalue" }) -join ';'
				}
			}
			
			Write-Log -Message "Here is old Reg (CLEANED):   $HKLMoldRegistry"
	
			# Before we set the PATH variable run it through a REGEX replace to remove any multiple semicolon issues
			$HKLMoldRegistry = $HKLMoldRegistry -replace "((;)\2+)",";"
			
			# Set the PATH environment variable with old Python junk removed 
			Set-RegistryKey -Key "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name 'Path' -Value "$HKLMoldRegistry" -Type 'ExpandString'

		}

		# Close any stuck InstallationProgress windows 
		Close-InstallationProgress

		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true
				 
		Show-InstallationProgress "Moving to Installation Phase....  Please Wait..."

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		
		Show-InstallationProgress "Installing $installTitle.... Please Wait..."
		
		#<Installation Code here>
				
		# Check if installer is not on local drive (I.e. C:\ drive). (Since it will fail from a UNC path I.e. \\filestore.nas...) 
		If (([System.Uri]$PSScriptRoot).IsUnc){
			Show-InstallationProgress "Detected Installer Running via Network UNC Path.. Copying Files Locally...."
			
			# Move file to main drive 
			New-Folder -Path "$envSystemDrive\temp\$appName"
			Copy-Item -Path "$dirFiles\*" -Destination "$envSystemDrive\temp\$appName" -Recurse
			
			# Install Application
			Show-InstallationProgress "Installing $installTitle (64bit).... This may take some time. Please Wait..."
			Execute-Process -Path "$envSystemDrive\temp\$appName\$appFile64" -Parameters "/quiet InstallAllUsers=1 InstallLauncherAllUsers=1 PrependPath=1" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'	

		}
		
		# Regular install (Since file isn't on filestore)(I.e. Installing via SCCM ccmcache)
		Else{
			# Install Application
			Show-InstallationProgress "Installing $installTitle (64bit).... This may take some time. Please Wait..."
			Execute-Process -Path "$dirFiles\$appFile64" -Parameters "/quiet InstallAllUsers=1 InstallLauncherAllUsers=1 PrependPath=1" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'	
		}
		
		# Remove temp leftover files
		If (Test-Path "$envSystemDrive\temp\$appName") {
			Remove-Folder -Path "$envSystemDrive\temp\$appName" -ContinueOnError $true
		} 

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		
		#Use ForEach loop to remove all icons from any User (Public, Users, etc. Desktop) declared in Variable Declaration...
		ForEach ($appIcon in $appIcons){
			$RemoveDesktopShortcuts = Get-ChildItem "$envSystemDrive\Users\*\Desktop\$appIcon.lnk"
			ForEach ($RemoveDesktopShortcut in $RemoveDesktopShortcuts){
				If ($RemoveDesktopShortcut | Test-Path){
					Show-InstallationProgress "Removing $appName Icons ($appIcon)... Please Wait..."
					Remove-File -Path "$RemoveDesktopShortcut" -ContinueOnError $true
				}
			}
		}
		
		#<Post-Installation Code here>

		Show-InstallationProgress "Setting $appName Environment Variables... Please wait..."

		# Set Java Home variable 
		Set-RegistryKey -Key "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name 'PYTHONPATH' -Value "$envProgramFiles\$appFolder;$envProgramFiles\$appFolder\Lib;$envProgramFiles\$appFolder\DLLs" -Type 'String'
		
		# Set Environmental Variable - to exceed the character count from 260 to 32,000
		Set-RegistryKey -Key  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value "1" -Type 'String'
		
		# Test to make sure PIP was installed with python (sometimes it doesn't install...)
		Show-InstallationProgress "Checking $appName PIP Installation. Please wait..."
		Execute-Process -Path "$envProgramFiles\$appFolder\$appRegName.exe" -Parameters "-m ensurepip --default-pi" -ContinueOnError $true -IgnoreExitCodes '*'	
		
		# Update PIP (sometimes pip can't install modules when out of date)
		Show-InstallationProgress "Checking $appName PIP for avaliable updates. Please wait..."
		Execute-Process -Path "$envProgramFiles\$appFolder\$appRegName.exe" -Parameters "-m pip install --upgrade pip" -ContinueOnError $true -IgnoreExitCodes '*'	
		
		
		# Start the pip exe and pass argument list with modules to install (For optional quiet mode use -NoNewWindow flag)
		Show-InstallationProgress "Installing $appName Modules. Please wait..."
		Start-Process "$envProgramFiles\$appFolder\Scripts\pip.exe" -ArgumentList "install $appPipModules" -NoNewWindow

		# Wait for pip to finish before moving on (Timeout in 600 seconds. In case Something locks up.)
		Show-InstallationProgress "Waiting for $appName Modules to Finish Installing..."
		
		Wait-Process -Name pip -Timeout 600
		
		# Create shortcut on StartMenu using New-Shortcut (64bit OS)
		New-Shortcut -Path "$envCommonStartMenuPrograms\$appName $appMajorVersion\Python $appMajorVersion (64-bit).lnk" -TargetPath "$envProgramFiles\$appFolder\$appRegName.exe" -IconLocation "$envProgramFiles\$appFolder\$appRegName.exe" -Description "Launches the Python $appMajorVersion interpreter." -WorkingDirectory "$envProgramFiles\$appFolder"
		New-Shortcut -Path "$envCommonStartMenuPrograms\$appName $appMajorVersion\Python $appMajorVersion Module Docs (64-bit).lnk" -TargetPath "$envProgramFiles\$appFolder\$appRegName.exe -m pydoc -b" -IconLocation "$envProgramFiles\$appFolder\$appRegName.exe" -Description "Start the Python $appMajorVersion documentation server." -WorkingDirectory "$envProgramFiles\$appFolder"

		# Add shortcut links to Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		If (Test-Path "$envCommonDesktop\Programs"){
			Copy-Item -Path "$envCommonStartMenuPrograms\$appName $appMajorVersion" -Destination "$envCommonDesktop\Programs\" -Recurse
		}
		
		# Close any stuck InstallationProgress windows 
		Close-InstallationProgress

		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "$installTitle is now Installed... If you have any questions please contact CENG IT Support." -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close app with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps "$appRuns" -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		## <Perform Uninstallation tasks here>

		Show-InstallationProgress "Searching For Old $appName Installation....  Please Wait..."
		
		#<Uninstallation Code here>
		
		# Search registery for any Python 3.* product
		$discoveredApps = Get-InstalledApplication -Name "$appName 3"
		
		# Grab the version numbers from the DisplayName, and  DisplayVersion / ProductCode (for really old Python 3)
		ForEach ($discoveredApp in $discoveredApps){
			$appDisplayName = $discoveredApp.DisplayName
			[version]$appDisplayVersion = $discoveredApp.DisplayVersion
			$appProductCode = $discoveredApp.ProductCode
			
			#Make sure we don't grab Anaconda 
			If (!($appDisplayName -like "*Anaconda*")){ 	
			
				#Check for really old Python 3.x Install (I.e. pre 3.5.0 , as these older versions used a MSI installer)
				If ($appDisplayVersion -ge "3.5.0"){
				
					#Extract the version from DisplayName					
					$appVersionFound = (Select-String -InputObject $appDisplayName -Pattern "(\d+(\.\w+){1,3})" -AllMatches).Matches
			
					#Add to an array of just found versions
					$appOldVersions += $appVersionFound
				}
				Else{
					#If older version, run the MSI uninstaller
					Show-InstallationProgress "Found Older MSI Python Install ($appDisplayVersion)... Removing, Please Wait..."					
					Execute-MSI -Action 'Uninstall' -Path "$appProductCode" -IgnoreExitCodes '*'
				}
			}	
		}
		
		#Sort the Array and remove duplicates
		$appOldVersions | Sort-Object
		$appOldVersions = $appOldVersions | Select-Object -Unique

		#Create temp folder
		New-Folder -Path "$envSystemDrive\temp\$appName"

		#Download the installers directly from Python (for the version/s found)
		ForEach ($appOldVersion in $appOldVersions){
			
			#This is for catching cases where a Python release canidate was installed. (I.E. Installers are called 3.5.2rc1.exe but fall under the 3.5.2 folder on the Python website)
			$TrimVersionFound = (Select-String -InputObject $appOldVersion -Pattern "(\d+(\.\d+){1,3})" -AllMatches).Matches
			
			Show-InstallationProgress "Found Python Version: $appOldVersion (Downloading Uninstaller python-$appOldVersion)"
			Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$TrimVersionFound/python-$appOldVersion.exe" -OutFile "$envSystemDrive\temp\$appName\python-$appOldVersion.exe"

			Show-InstallationProgress "Found Python Version: $appOldVersion (Downloading Uninstaller python-$appOldVersion-amd64)"
			Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$TrimVersionFound/python-$appOldVersion-amd64.exe" -OutFile "$envSystemDrive\temp\$appName\python-$appOldVersion-amd64.exe"
		
			#Run the uninstall process 
			If (Test-Path "$envSystemDrive\temp\$appName\python-$appOldVersion.exe"){
				Show-InstallationProgress "Uninstalling Old Python Install ($appOldVersion)... Please Wait..."
				Execute-Process -Path "$envSystemDrive\temp\$appName\python-$appOldVersion.exe" -Parameters '/uninstall /quiet' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				#Wait for uninstaller to close
				Start-sleep -s 5
			}	

			If (Test-Path "$envSystemDrive\temp\$appName\python-$appOldVersion-amd64.exe"){
				Show-InstallationProgress "Uninstalling Old Python Install ($appOldVersion-amd64)... Please Wait..."
				Execute-Process -Path "$envSystemDrive\temp\$appName\python-$appOldVersion-amd64.exe" -Parameters '/uninstall /quiet' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				#Wait for uninstaller to close
				Start-sleep -s 5
			}	
		}	

		If (Get-InstalledApplication -Name "Python Launcher"){
			Show-InstallationProgress "Uninstalling Old Python Launcher... Please Wait..."
			Remove-MSIApplications -Name "Python Launcher"
		}	
		
		# Remove Leftover ProgramFiles Folders
		$appOLD32Installs = Get-ChildItem "$envProgramFiles\Python3*"
		ForEach ($appOLD32Install in $appOLD32Installs) {
			$removing1 = "" + $appOLD32Install
			# if statement to check if variable is null
			If ($removing1 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Folders....  Please Wait..."
				Remove-Folder -Path "$removing1" -ContinueOnError $true
			}
		}	
		
		# Remove Leftover ProgramFiles Folders
		$appOLD64Installs = Get-ChildItem "$envProgramFilesX86\Python3*"
		ForEach ($appOLD64Install in $appOLD64Installs) {
			$removing2 = "" + $appOLD64Install
			# if statement to check if variable is null
			If ($removing2 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Folders....  Please Wait..."
				Remove-Folder -Path "$removing2" -ContinueOnError $true
			}
		}	
		
		# Remove StartMenu Shortcuts
		$appOldStartMenus = Get-ChildItem "$envCommonStartMenuPrograms\Python 3*"
		ForEach ($appOldStartMenu in $appOldStartMenus) {
			$removing = "" + $appOldStartMenu
			# if statement to check if variable is null
			If ($removing | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Shortcuts....  Please Wait..."
				Remove-Folder -Path "$removing" -ContinueOnError $true
			}
		}	
		
		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$appOldLabShorts = Get-ChildItem "$envCommonDesktop\Programs\Python 3*"
		ForEach ($appOldLabShort in $appOldLabShorts) {
			$removing3 = "" + $appOldLabShort
			# if statement to check if variable is null
			If ($removing3 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName Shortcuts....  Please Wait..."
				Remove-Folder -Path "$removing3" -ContinueOnError $true
			}
		}	
		
		# Remove any leftover registry leftovers 
		Show-InstallationProgress "Checking for old Registry Entries...  Please Wait..."
		Remove-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore\3*" -Recurse
		Remove-Item -Path "HKLM:\SOFTWARE\Python\PythonCore\3*" -Recurse

		# Remove old ENV key
		Remove-RegistryKey -Key  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "PYTHONPATH" -ContinueOnError $true

		# Check the PATH variable and remove any Python stuff 
		$HKLMoldRegistry = Get-RegistryKey -Key "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value "Path"
		$HKLMoldRegistry = "" + "$HKLMoldRegistry"
		
		Write-Log -Message "Here is old Reg:   $HKLMoldRegistry"
		
		# Check if there is a possible existing value in PATH 
		If ($HKLMoldRegistry -like '*Python3*'){
		
			Show-InstallationProgress "Preexisting $appName Environment Variable Detected... Please Wait..."
			
			# Split the PATH environment variable and store it in an array
			$HKLMoldRegistryArray = $HKLMoldRegistry.Split(';')
			
			# Go through the array and pull any value that maches the java jdk (loop for any multiple entries)
			ForEach ($HKLMoldRegistryArrayValue in $HKLMoldRegistryArray){
				If ($HKLMoldRegistryArrayValue -like '*Python3*'){
					$HKLMoldPATHvalue = $HKLMoldRegistryArrayValue
					
					Show-InstallationProgress "Preexisting $appName Environment Variable : $HKLMoldPATHvalue ..."
					
					# This will split the PATH environment variable and remove the JDK value found then rejoin the array into a string
					$HKLMoldRegistry = ($HKLMoldRegistry.Split(';') | Where-Object { $_ -ne "$HKLMoldPATHvalue" }) -join ';'
				}
			}
			
			Write-Log -Message "Here is old Reg (CLEANED):   $HKLMoldRegistry"
	
			# Before we set the PATH variable run it through a REGEX replace to remove any multiple semicolon issues
			$HKLMoldRegistry = $HKLMoldRegistry -replace "((;)\2+)",";"
			
			# Set the PATH environment variable with old Python junk removed 
			Set-RegistryKey -Key "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name 'Path' -Value "$HKLMoldRegistry" -Type 'ExpandString'

		}

		# Close any stuck InstallationProgress windows 
		Close-InstallationProgress

		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true
		
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
