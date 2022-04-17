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
	[string]$appVendor = 'Cadence Design Systems, Inc.'
	[string]$appName = 'AWR Design Environment'
	[string]$appRegName = 'AWR Design Environment'
	[string]$appVersion = '15.04.10117.2'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.3.1'
	[string]$appScriptDate = '4/16/2022'
	[string]$appScriptAuthor = 'Payton Climer'
	[string]$appFile = 'Update_AWR15.04.000_wint_1of1.exe'
	[string]$appUpdateFile = ''
	[string]$appLicense = 'AWRD_LICENSE_FILE'
	[string]$appLicenseInfo = 'port@license.server'
	[array]$appIcons = @()
	[string]$appRuns = "MWOffice,analyst"
	##*===============================================
	
	##*===============================================
	##* Update ChangeLog
	##*===============================================
	##
	## Version 1.0.0 
	##		- Initial version (10/04/2018)
	##		- Using AWR 14.01.9173.5
	## 	
	## Version 1.1.0 (11/10/2020)
	##		- Moved to AppDeployToolkit version 3.8.2
	##		- Using AWR v15.02.10080.4 (Now called Cadence AWR Design Environment)
	##		- Using new license port since now under Cadence (5283@ceng-licmgr4)
	##
	## Version 1.2.0 (12/21/2020)
	##		- Moved to AWR 15.03.10088.1
	##		- Added a /noreboot flag to installer 
	##
	## Version 1.3.0 (5/3/2021)
	##		- Moved to AppDeployToolkit version 3.8.4
	##		- Moved to AWR 15.04.10117.2
	##
	## Version 1.3.1 (4/16/2022)
	##		- Code Cleanup 
	##
	##		- WARNING PSAPPDEPLOY CHANGE:
	##			- When runnng Execute-Process commands their is new handling of exit codes
	##			- I.e. ignore error 1 ( Execute-Process -Path "" -Parameters "" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '1' )
	##			- I.e. ignore any error ( Execute-Process -Path "" -Parameters "" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*' )
	##			- Read the release notes for more info ( https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/releases ) 
	##
	##*===============================================
	
	##*===============================================
	##* Installer Notes
	##*===============================================
	##	Software uses the DotNetInstaller exe wrapper which installs an MSI package.
	##
	##	Download latest version from Cadence downloads website (https://downloads.cadence.com/) (Need credentials)
	##
	##	Silent installer flag uses the following
	##		Base_AWR1x.xx.xxx_wint_1of1.exe /i /q /noreboot
	##
	##	Silent uninstall follows typical MSI
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
		
		# Check if running 32bit OS and EXIT if True (This package doesn't support 32bit OS)
		if ($psArchitecture -eq "x86") {
			Show-InstallationPrompt -Message "ERROR: This APP Package Does Not Include 32bit OS Support... Please Contact CENG IT Support About a Computer Upgrade...." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}
		
		Show-InstallationProgress "Searching For Old $appName Installation....  Please Wait..."
		
		#<Pre-Installation Code here>
		
		# Uninstall any old version before continuing
		If (Get-InstalledApplication -Name "$appRegName"){
			Show-InstallationProgress "Detected a previous $appRegName install... Uninstalling, please wait..."
			Remove-MSIApplications "$appRegName"
		}
		
		# Remove any Program File Leftovers
		If (Test-Path "$envProgramFilesX86\AWR"){
			Show-InstallationProgress "Removing Old $appName Installation....  Please Wait..."
			Remove-Folder -Path "$envProgramFilesX86\AWR" -ContinueOnError $true
		}
		
		# Remove any Program Data Leftovers
		If (Test-Path "$envProgramData\AWR"){
			Show-InstallationProgress "Removing Old $appName Leftovers....  Please Wait..."
			Remove-Folder -Path "$envProgramData\AWR" -ContinueOnError $true
		}
		
		# Remove any User Desktop shortcuts (Software will create shortcut in single user)
		$oldDesktopShortcuts = Get-ChildItem "$envSystemDrive\Users\*\Desktop\AWRDE *"
		ForEach ($oldDesktopShortcut in $oldDesktopShortcuts) {
			If ($oldDesktopShortcut | Test-Path) {
				Show-InstallationProgress "Removing Old $appName shortcut....  Please Wait..."
				Remove-Folder -Path "$oldDesktopShortcut" -ContinueOnError $true
			}
		}
		
		# Remove any User StartMenu shortcuts
		$oldStartMenuShortcuts = Get-ChildItem "$envSystemDrive\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\AWRDE *"
		ForEach ($oldStartMenuShortcut in $oldStartMenuShortcuts) {
			If ($oldStartMenuShortcut | Test-Path) {
				Show-InstallationProgress "Removing Old $appName shortcut....  Please Wait..."
				Remove-Folder -Path "$oldStartMenuShortcut" -ContinueOnError $true
			}
		}
		
		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$oldLabDesktopShortcuts = Get-ChildItem "$envCommonDesktop\Programs\AWRDE *"
		ForEach ($oldLabDesktopShortcut in $oldLabDesktopShortcuts) {
			If ($oldLabDesktopShortcut | Test-Path) {
				Show-InstallationProgress "Removing Old $appName shortcut....  Please Wait..."
				Remove-Folder -Path "$oldLabDesktopShortcut" -ContinueOnError $true
			}
		}
		
		# Remove any Existing Environment Variable
		Remove-RegistryKey -Key  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "$appLicense" -ContinueOnError $true
		
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
		
		# Install using exe package
		Execute-Process -Path "$appFile" -Parameters "/i /q /noreboot" -ContinueOnError $true -IgnoreExitCodes '*'
		

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

		# Add shortcut links to Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		If (Test-Path "$envCommonDesktop\Programs"){
			Copy-Item -Path "$envCommonStartMenuPrograms\AWRDE *" -Destination "$envCommonDesktop\Programs\" -Recurse
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
		
		# Uninstall any old version before continuing
		If (Get-InstalledApplication -Name "$appRegName"){
			Show-InstallationProgress "Detected a previous $appRegName install... Uninstalling, please wait..."
			Remove-MSIApplications "$appRegName"
		}
		
		# Remove any Program File Leftovers
		If (Test-Path "$envProgramFilesX86\AWR"){
			Show-InstallationProgress "Removing Old $appName Installation....  Please Wait..."
			Remove-Folder -Path "$envProgramFilesX86\AWR" -ContinueOnError $true
		}
		
		# Remove any Program Data Leftovers
		If (Test-Path "$envProgramData\AWR"){
			Show-InstallationProgress "Removing Old $appName Leftovers....  Please Wait..."
			Remove-Folder -Path "$envProgramData\AWR" -ContinueOnError $true
		}
		
		# Remove any User Desktop shortcuts (Software will create shortcut in single user)
		$oldDesktopShortcuts = Get-ChildItem "$envSystemDrive\Users\*\Desktop\AWRDE *"
		ForEach ($oldDesktopShortcut in $oldDesktopShortcuts) {
			If ($oldDesktopShortcut | Test-Path) {
				Show-InstallationProgress "Removing Old $appName shortcut....  Please Wait..."
				Remove-Folder -Path "$oldDesktopShortcut" -ContinueOnError $true
			}
		}
		
		# Remove any User StartMenu shortcuts
		$oldStartMenuShortcuts = Get-ChildItem "$envSystemDrive\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\AWRDE *"
		ForEach ($oldStartMenuShortcut in $oldStartMenuShortcuts) {
			If ($oldStartMenuShortcut | Test-Path) {
				Show-InstallationProgress "Removing Old $appName shortcut....  Please Wait..."
				Remove-Folder -Path "$oldStartMenuShortcut" -ContinueOnError $true
			}
		}
		
		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$oldLabDesktopShortcuts = Get-ChildItem "$envCommonDesktop\Programs\AWRDE *"
		ForEach ($oldLabDesktopShortcut in $oldLabDesktopShortcuts) {
			If ($oldLabDesktopShortcut | Test-Path) {
				Show-InstallationProgress "Removing Old $appName shortcut....  Please Wait..."
				Remove-Folder -Path "$oldLabDesktopShortcut" -ContinueOnError $true
			}
		}
		
		# Remove any Existing Environment Variable
		Remove-RegistryKey -Key  "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "$appLicense" -ContinueOnError $true
		
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
