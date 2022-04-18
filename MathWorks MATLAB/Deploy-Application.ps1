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
	[string]$appVendor = 'MathWorks'
	[string]$appName = 'MATLAB'
	[string]$appRegName = 'MATLAB'
	[string]$appVersion = 'R2022a'
	[string]$appArch = 'win64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.1.0'
	[string]$appScriptDate = '4/12/2022'
	[string]$appScriptAuthor = 'Payton Climer'
	[string]$appFile = 'setup.exe'
	[string]$appUpdateFile = ''
	[string]$appVHDXFile = 'Matlab2022A.vhdx'
	[string]$appLicense = 'MLM_LICNESE_FILE'
	[string]$appLicenseInfo = 'port@license.server'
	[array]$appAddFirewalls = @('matlab.exe','supportsoftwareinstaller.exe','java.exe','mwdocsearch.exe')
	[array]$appIcons = @( )
	[string]$appRuns = "MATLAB"
	##*===============================================
	
	##*===============================================
	##* Update ChangeLog
	##*===============================================
	##
	## Version 1.0.0 (3/29/2022)
	##		- Branched code from R2021a 
	##		- Using AppDeployToolkit version 3.8.4
	##		- Using MATLAB version R2022a
	##		- Matlab fixed issue in this version, no longer requires running setup.exe from (Installer Files\bin\win64) folder.
	##			- This fixes installer crashing / running out memory when SCCM runs installer under SYSTEM User account. 
	##
	## Version 1.1.0 (4/12/2022)
	##		- New simpler UNC path check code
	##		- Code cleanup
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
	##	Software uses Java based exe Installer
	##
	##	Download latest version from Matlab website (Need credentials / License)
	##
	##	Create and pack all Matlab installer files in a vhdx file archive.
	##		- This reduces Download times, and you don't unpack files (can install directly through mounted vhdx) 
	##
	##	Modify new version activate.ini and installer_input.txt and place under SupportFiles (use existing as template)
	##		- Get fileInstallationKey for your site (unique to each version).
	##		- Get activationKey for your site.
	##		- Get the latest license.dat for your site (Matlab needs this file during install process).
	##
	##	Silent installer flag uses the following
	##		setup.exe -inputFile installer_input.txt
	##
	##	Silent uninstall flag uses the following
	##		uninstall.exe -mode silent
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

		## Show Welcome Message, close app if required, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps "$appRuns" -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>
		
		# Check if running 32bit OS and EXIT if True (This package doesn't support 32bit OSes)
		if ($psArchitecture -eq "x86") {
			Show-InstallationPrompt -Message "ERROR: This APP Package Does Not Include 32bit OS Support... Please Contact CENG IT Support About a Computer Upgrade...." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}
		
		Show-InstallationProgress "Searching For Old $appName Installation....  This may take some time. Please Wait..."
		
		#<Pre-Installation Code here>
		
		# Search for Program Files Uninstall (C:\ProgramFiles\MATLAB)
		[array]$appOldInstalls = Get-ChildItem -Path "$envProgramFiles\$appName\*" -Filter "uninstall.exe" -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
		ForEach ($appOldInstall in $appOldInstalls){
				
			If ($appOldInstall | Test-Path) {
				Show-InstallationProgress "Uninstalling Old $appName $appOldInstall Installation....  This will take some time. Please Wait..."
				Execute-Process -Path "$appOldInstall" -Parameters '-mode silent' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
			}
			Else {
				# This error should never occur but here you go
				Show-InstallationProgress "Error: Uninstall File Missing for $appOldInstall ... Continuing..."
			}			
		}
		
		# Search for Program Files Uninstall (C:\MATLAB)
		[array]$appOldInstalls2 = Get-ChildItem -Path "$envSystemDrive\$appName\*" -Filter "uninstall.exe" -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
		ForEach ($appOldInstall2 in $appOldInstalls2){
				
			If ($appOldInstall2 | Test-Path) {
				Show-InstallationProgress "Uninstalling Old $appName $appOldInstall2 Installation....  This will take some time. Please Wait..."
				Execute-Process -Path "$appOldInstall2" -Parameters '-mode silent' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
			}
			Else {
				# This error should never occur but here you go
				Show-InstallationProgress "Error: Uninstall File Missing for $appOldInstall2 ... Continuing..."
			}			
		}
		
		# Remove any old environment variables
		Remove-RegistryKey -Key  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "$appLicense" -ContinueOnError $true
		
		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$appOldDesktopFiles = Get-ChildItem "$envCommonDesktop\Programs\$appName *"
		ForEach ($appOldDesktopFile in $appOldDesktopFiles) {
			$removing2 = "" + $appOldDesktopFile
			# if statement to check if variable is null
			If ($removing2 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing2" -ContinueOnError $true
			}
		}

		# Remove any leftover startmenu shortcuts
		$appOldStartFiles = Get-ChildItem "$envCommonStartMenuPrograms\$appName *"
		ForEach ($appOldStartFile in $appOldStartFiles) {
			$removing3 = "" + $appOldStartFile
			# if statement to check if variable is null
			If ($removing3 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing3" -ContinueOnError $true
			}
		}
		
		# Remove any leftover Program Files
		$appLeftoverFiles = Get-ChildItem "$envProgramFiles\$appName\R*"
		ForEach ($appLeftoverFile in $appLeftoverFiles) {
			$removing4 = "" + $appLeftoverFile
			# if statement to check if variable is null
			If ($removing4 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing4" -ContinueOnError $true
			}
		}
		
		# Remove any leftover Program Files
		$appLeftoverFiles2 = Get-ChildItem "$envSystemDrive\$appName\R*"
		ForEach ($appLeftoverFile2 in $appLeftoverFiles2) {
			$removing5 = "" + $appLeftoverFile2
			# if statement to check if variable is null
			If ($removing5 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing5" -ContinueOnError $true
			}
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
		
		#Create Folder and move necessary files over for installation
		New-Folder -Path "$envProgramFiles\$appRegName\$appVersion"
		Copy-Item -Path "$dirSupportFiles\*" -Destination "$envProgramFiles\$appRegName\$appVersion" -Recurse
		
		# This installer has issues when running on network shares.
		# Check if installer is not on local drive (I.e. C:\ drive). (Since it will fail from a UNC path) 
		If (([System.Uri]$PSScriptRoot).IsUnc){
		
			Show-InstallationProgress "Detected Installer Running via Network Path.. Copying Files Locally...."
			
			# Move vhdx file to main drive 
			New-Folder -Path "$envSystemDrive\temp\$appName"
			Copy-Item -Path "$dirFiles\*" -Destination "$envSystemDrive\temp\$appName" -Recurse
			
			#Mount the VHDX file 
			try {
				Show-InstallationProgress "Mounting $installTitle VHDX files... Please Wait..."
				Mount-DiskImage -ImagePath "$envSystemDrive\temp\$appName\$appVHDXFile" -Access ReadWrite -PassThru
			}
			
			catch {
				Show-InstallationPrompt -Message "ERROR: Unable to mount installer files for installation... Unable to continue." -ButtonRightText 'EXIT' -Icon Information -NoWait
				Exit $mainExitCode
			}
			
			#Get the assigned Drive Letter
			$DriveLetter = (Get-Partition (Get-DiskImage -ImagePath "$envSystemDrive\temp\$appName\$appVHDXFile" ).Number | Get-Volume).DriveLetter

			# Install Matlab using the setup.exe
			Show-InstallationProgress "Installing $installTitle.... Please Don't Turn off your PC. This may take over 30 minutes..."

			Execute-Process -Path "$DriveLetter`:\$appFile" -Parameters "-inputFile `"$envProgramFiles\$appName\$appVersion\installer_input.txt`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
	
			# Waiting for Installer setup.exe (catches a rare issue where Matlab switches which setup.exe it's using)
			Wait-Process -Name setup -Timeout 1800

			# Refresh the desktop 
			Update-Desktop -ContinueOnError $true
			
			#Unmount the VHDX
			Dismount-DiskImage -ImagePath "$envSystemDrive\temp\$appName\$appVHDXFile" -Confirm:$false
		}	
		
		Else{
			
			#Mount the VHDX file 
			try {
				Show-InstallationProgress "Mounting $installTitle VHDX files... Please Wait..."
				Mount-DiskImage -ImagePath "$dirFiles\$appVHDXFile" -Access ReadWrite -PassThru
			}
			
			catch {
				Show-InstallationPrompt -Message "ERROR: Unable to mount installer files for installation... Unable to continue." -ButtonRightText 'EXIT' -Icon Information -NoWait
				Exit $mainExitCode
			}
			
			#Get the assigned Drive Letter
			$DriveLetter = (Get-Partition (Get-DiskImage -ImagePath "$dirFiles\$appVHDXFile" ).Number | Get-Volume).DriveLetter
			
			# Install Matlab using the setup.exe
			Show-InstallationProgress "Installing $installTitle.... Please Don't Turn off your PC. This may take over 30 minutes..."

			Execute-Process -Path "$DriveLetter`:\$appFile" -Parameters "-inputFile `"$envProgramFiles\$appName\$appVersion\installer_input.txt`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'

			# Waiting for Installer setup.exe (catches a rare issue where Matlab switches which setup.exe it's using)
			Wait-Process -Name setup -Timeout 1800

			# Refresh the desktop 
			Update-Desktop -ContinueOnError $true

			#Unmount the VHDX
			Dismount-DiskImage -ImagePath "$dirFiles\$appVHDXFile" -Confirm:$false
		}
		
		# Remove temp leftover files
		If (Test-Path "$envSystemDrive\temp\$appName") {
			Show-InstallationProgress "Removing $appName Installer Files...Please Wait..."
			Remove-Folder -Path "$envSystemDrive\temp\$appName" -ContinueOnError $true
		} 

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		
		#Use ForEach loop to remove all icons from any User (Public, Users, etc. Desktop) declared in Variable Declaration...
		ForEach ($appIcon in $appIcons)
		{
			$RemoveDesktopShortcuts = Get-ChildItem "$envSystemDrive\Users\*\Desktop\$appIcon.lnk"
			ForEach ($RemoveDesktopShortcut in $RemoveDesktopShortcuts) {
				If ($RemoveDesktopShortcut | Test-Path) {
					Show-InstallationProgress "Removing $appName Icons ($appIcon)... Please Wait..."
					Remove-File -Path "$RemoveDesktopShortcut" -ContinueOnError $true
				}
			}
		}
		
		#<Post-Installation Code here>
		
		# Set the Environment Variable for Licensing 
		Show-InstallationProgress "Setting $appName Environment Variable. Please wait..."
		[System.Environment]::SetEnvironmentVariable("$appLicense", "$appLicenseInfo",[System.EnvironmentVariableTarget]::Machine)
		
		# Set any firewall rules 
		Show-InstallationProgress "Setting $appName Firewall Rules... Please wait..."
		
		# Use array above to set Firewall rules using Get-ChildItem to find full path  
		ForEach ($appAddFirewall in $appAddFirewalls){
			[array]$appFirewalls = Get-ChildItem -Path "$envProgramFiles\$appName\*" -Filter $appAddFirewall -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
			ForEach ($appFirewall in $appFirewalls){
				If ($appFirewall | Test-Path){
					Show-InstallationProgress "Adding Firewall Entry for $appFirewall ... Please Wait..."
					Execute-Process -FilePath “$envSystemDrive\Windows\System32\netsh.exe” -Arguments "advfirewall firewall add rule name=""$appName $appVersion - $appAddFirewall"" dir=in action=allow profile=any program=""$appFirewall""" -IgnoreExitCodes '*'
				}
				Else{
					# This error should never occur but here you go
					Show-InstallationProgress "Error: File Missing for $appFirewall ... Continue..."
				}			
			}
		}
		
		# Check that startmenu shortcut is created (Create if not)
		If (!(Test-Path "$envCommonStartMenuPrograms\$appRegName $appVersion")){
			Show-InstallationProgress "Creating $appName Shortcuts. Please wait..."
			
			New-Folder -Path "$envCommonStartMenuPrograms\$appRegName $appVersion"
			New-Shortcut -Path "$envCommonStartMenuPrograms\$appRegName $appVersion\$appRegName $appVersion.lnk" -TargetPath "$envProgramFiles\$appRegName\$appVersion\bin\$appRegName.exe" -IconLocation "$envProgramFiles\$appRegName\$appVersion\bin\$appRegName.exe" -Description "Start MATLAB - The Language of Technical Computing" -WorkingDirectory " "
		}
		
		# Add shortcut links to Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		If (Test-Path "$envCommonDesktop\Programs"){
			Copy-Item -Path "$envCommonStartMenuPrograms\$appName *" -Destination "$envCommonDesktop\Programs\" -Recurse
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
		
		# Search for Program Files Uninstall (C:\ProgramFiles\MATLAB)
		[array]$appOldInstalls = Get-ChildItem -Path "$envProgramFiles\$appName\*" -Filter "uninstall.exe" -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
		ForEach ($appOldInstall in $appOldInstalls){
				
			If ($appOldInstall | Test-Path) {
				Show-InstallationProgress "Uninstalling Old $appName $appOldInstall Installation....  This will take some time. Please Wait..."
				Execute-Process -Path "$appOldInstall" -Parameters '-mode silent' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
			}
			Else {
				# This error should never occur but here you go
				Show-InstallationProgress "Error: Uninstall File Missing for $appOldInstall ... Continuing..."
			}			
		}
		
		# Search for Program Files Uninstall (C:\MATLAB)
		[array]$appOldInstalls2 = Get-ChildItem -Path "$envSystemDrive\$appName\*" -Filter "uninstall.exe" -Recurse -ErrorAction SilentlyContinue -Force | % { $_.FullName }
		ForEach ($appOldInstall2 in $appOldInstalls2){
				
			If ($appOldInstall2 | Test-Path) {
				Show-InstallationProgress "Uninstalling Old $appName $appOldInstall2 Installation....  This will take some time. Please Wait..."
				Execute-Process -Path "$appOldInstall2" -Parameters '-mode silent' -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
			}
			Else {
				# This error should never occur but here you go
				Show-InstallationProgress "Error: Uninstall File Missing for $appOldInstall2 ... Continuing..."
			}			
		}
		
		# Remove any old environment variables
		Remove-RegistryKey -Key  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "$appLicense" -ContinueOnError $true
		
		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$appOldDesktopFiles = Get-ChildItem "$envCommonDesktop\Programs\$appName *"
		ForEach ($appOldDesktopFile in $appOldDesktopFiles) {
			$removing2 = "" + $appOldDesktopFile
			# if statement to check if variable is null
			If ($removing2 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing2" -ContinueOnError $true
			}
		}

		# Remove any leftover startmenu shortcuts
		$appOldStartFiles = Get-ChildItem "$envCommonStartMenuPrograms\$appName *"
		ForEach ($appOldStartFile in $appOldStartFiles) {
			$removing3 = "" + $appOldStartFile
			# if statement to check if variable is null
			If ($removing3 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing3" -ContinueOnError $true
			}
		}
		
		# Remove any leftover Program Files
		$appLeftoverFiles = Get-ChildItem "$envProgramFiles\$appName\R*"
		ForEach ($appLeftoverFile in $appLeftoverFiles) {
			$removing4 = "" + $appLeftoverFile
			# if statement to check if variable is null
			If ($removing4 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing4" -ContinueOnError $true
			}
		}
		
		# Remove any leftover Program Files
		$appLeftoverFiles2 = Get-ChildItem "$envSystemDrive\$appName\R*"
		ForEach ($appLeftoverFile2 in $appLeftoverFiles2) {
			$removing5 = "" + $appLeftoverFile2
			# if statement to check if variable is null
			If ($removing5 | Test-Path) {
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removing5" -ContinueOnError $true
			}
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
