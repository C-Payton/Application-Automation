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
	[string]$appVendor = 'Cadence'
	[string]$appName = 'OrCAD & Allegro'
	[string]$appRegName = "Cadence OrCAD and Allegro 17.4-2019"
	[string]$appVersion = '17.40.000'
	[string]$appPatchVersion = '17.40.028'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.9.0'
	[string]$appScriptDate = '4/18/2022'
	[string]$appScriptAuthor = 'CENG IT - Payton Climer'
	[string]$appVHDXFile = 'Cadence174.vhdx'
	[string]$appFile = 'setup.exe'
	[string]$appHotfixFile = 'Hotfix_SPB17.40.028'
	[string]$appHotfixInstall = 'silentinstallHotfix-SPB.ini'
	[string]$appInstall = 'silentinstall-SPB.ini'
	[string]$appUninstallOrCAD = 'uninstallOrCAD_blank.iss'
	[string]$appUninstallOrCAD174 = 'uninstallOrCAD174_blank.iss'
	[string]$appUninstallDLmanager = 'uninstallDLmanager_blank.iss'
	[string]$appLicense = 'CDS_LIC_FILE'
	[string]$appLicenseInfo = 'port@license.server'
	[string]$appDriveSpaceNeeded = '30'
	[array]$appIcons = @( )
	[string]$appRuns = "capture,allegro,pspice,pspiceaa,Downloadmanager"
	##*===============================================
	
	##*===============================================
	##* Update ChangeLog
	##*===============================================
	##
	## Version 1.0.0 
	##		- Initial version 
	##		- Using Cadence OrCAD and Allegro 17.2 - 2016
	##
	## Version 1.0.1 
	##		- Added Uninstallation Support
	##			- Includes massive cleanup scripting for leftover files after uninstallation
	##
	## Version 1.1.0
	##		- Complete Re-Write 
	##			- Code Improvements 
	##		- Moved to AppDeployToolkit version 3.7.0
	##		- AppDeployToolkit Branding Images Updated 
	##
	## Version 1.2.0 (Payton 3/18/2019)
	##		- Code Improvements 
	##		- new uninstall code (removes the old ProductCode based search)
	##		- Added Hotfix_SPB17 v17.20.047
	##
	## Version 1.2.1 (Payton 3/19/2019)
	##		- Small Bug Fix
	##			- Forgot to change uninstall code section 
	##
	## Version 1.3.0 (Payton 5/3/2019)
	##		- Added Hotfix_SPB17 v17.20.054
	##
	## Version 1.3.0 (Payton 5/7/2019)
	##		- Changed Environment Variable set method 
	##
	## Version 1.4.0 (Payton 11/6/2019)
	##		- Branched code for new 17.40.000 major release. 
	##		- Moved to AppDeployToolkit version 3.8.0
	##		- Added code to check if hotfix file exists 
	##			- Note: No hotfixes avaliable for 17.40.000 at this time.
	##				- Variable values populated with previous version.
	##
	## Version 1.5.0 (7/20/2020)
	##		- Moved to AppDeployToolkit version 3.8.2
	##		- Added Cadence Hotfix v17.40.008
	##			- Note: Cadence has changed how they package Updates, they are now zipped.
	##		- Code updates 
	##			- Removed builtin drivespace check and added code for a set value 
	##			- Variable $appDriveSpaceNeeded is how much freespace in GB is needed.
	##				- Note the estimation is a little high, but this accounts for Base and Hotfix.
	##
	## Version 1.6.0 (7/22/2020)
	##		- Moving to new VHDX packed installer method. 
	##			- This should reduce download times, less hash checks, no more unpacking zips.
	##		- Moved the Hotfix to the $dirFiles instead of $dirSupportFiles
	##
	## Version 1.7.0 (9/10/2021)
	##		- Moved to AppDeployToolkit version 3.8.4
	##		- Added Cadence Hotfix v17.40.020
	##
	## Version 1.7.1 (9/13/2021)
	##		- Added code to address failure to install over Task Sequence
	##
	## Version 1.7.2 (9/14/2021)
	##		- Fixed possible bug with deploy and TaskSequences 
	##
	## Version 1.8.0 (12/22/2021)
	##		- Added Cadence Hotfix v17.40.025
	##			- Important Patch for Log4j vulnerability
	##
	## Version 1.9.0 (4/18/2022)
	##		- Added Cadence Hotfix v17.40.028
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
	##	Software uses InstallShield wrapper with the provided silentinstall-SPB.ini (Base) and silentinstallHotfix-SPB.ini (Hotfix) files
	##
	##	Download latest version from Cadence website (https://downloads.cadence.com/) (Need a login)
	##	
	##	Create and pack all Cadence installer files in a VHDX file archive.
	##		- Reduces Download times, and you don't unpack files (can install directly through mounted VHDX) 
	##
	##	Modify new version silentinstallHotfix-SPB.ini and silentinstall-SPB.ini and place under SupportFiles (use existing as template)
	##
	##	Silent installer flag uses the following
	##		Base:   setup.exe -SMS -w !quiet="silentinstall-SPB.ini"
	##		Hotfix: setup.exe -SMS !quiet="silentinstallHotfix-SPB.ini" 
	##
	##	Silent uninstall flag uses the following
	##		$envProgramFilesX86\InstallShield Installation Information\*\AllegroDownloadManager.exe -s -f1"uninstall*_blank.iss" -SMS -uninst
	##		$envProgramFilesX86\InstallShield Installation Information\*\setup.exe -s -f1"uninstall*_blank.iss" -SMS -uninst
	##		$envProgramFilesX86\InstallShield Installation Information\*\installsetup.exe -s -f1"uninstall*_blank.iss" -SMS -uninst
	##
	##		NOTE: To generate an iss file with InstallShield, you need to install the applciation. And then run the setup.exe with a -r flag to record the inputs for the uninstall.
	##			  Uninstall Record.iss file is modified to remove the GUID that way we
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
		If ($psArchitecture -eq "x86"){
			Show-InstallationPrompt -Message "ERROR: This APP Package Does Not Include 32bit OS Support... Please Contact CENG IT Support About a Computer Upgrade...." -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}
		
		# Check for enough free disk space for install ( Installer will fail if there isn't enough space. )
		$appDriveSpace = Get-FreeDiskSpace -Drive "$envSystemDrive"
		$appDriveSpaceGB = [math]::Round($appDriveSpace / 1024)
		If ($appDriveSpaceGB -lt $appDriveSpaceNeeded){
			Show-InstallationPrompt -Message "ERROR: There is Not Enough Available Disk Space for $appVendor Installation... Current Disk Space ($appDriveSpaceGB GB) Minimum Needed ($appDriveSpaceNeeded GB) " -ButtonRightText 'EXIT' -Icon Information -NoWait
			Exit $mainExitCode
		}
		
		Show-InstallationProgress "Searching For Old $appName Installation....  Please Wait..."
		
		#<Pre-Installation Code here>
		
		# This code section is for just installing patches for existing Cadence 17.4 installs 
		
		[string]$appDisplayVersion = (Get-InstalledApplication -Name "$appRegName") | select DisplayVersion -expand DisplayVersion
		
		#Check if a previous Cadence install is detected (Patch any existing 17.4 installs, and anything else will go uninstall and install)
		If (Get-InstalledApplication -Name "$appRegName"){
			
			# If you are running this and it detects you are already running the latest patch (Exit the code)
			If ($appDisplayVersion -ge $appPatchVersion){
				If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "Latest $installTitle already installed... If you have any questions please contact CENG IT Support." -ButtonRightText 'OK' -Icon Information -NoWait }
				Exit-Script -ExitCode 0	
			}
			
			# Patch any existing Cadence 17.4 install if detected
			ElseIf ($appDisplayVersion -ge 17.4.0){
			
				# Close any stuck InstallationProgress windows 
				Close-InstallationProgress
				
				Show-InstallationProgress "Detected a Newer $appName Install... Attempting $appPatchVersion Patch... Upacking Update Files... Please Wait..."
				
				# This installer has issues when running on network shares.
				# Check if installer is not on local drive (I.e. C:\ drive). (Since it will fail from a UNC...) 
				If (([System.Uri]$PSScriptRoot).IsUnc){
					
					# Move file to main drive 
					New-Folder -Path "$envSystemDrive\temp\$appVendor"
					Copy-Item -Path "$dirFiles\*" -Destination "$envSystemDrive\temp\$appVendor" -Recurse
					Copy-Item -Path "$dirSupportFiles\*" -Destination "$envSystemDrive\temp\$appVendor" -Recurse
			
					#Mount the VHDX file 
					try {
						Show-InstallationProgress "Mounting $installTitle VHDX files... Please Wait..."
						Mount-DiskImage -ImagePath "$envSystemDrive\temp\$appVendor\$appVHDXFile" -Access ReadOnly -PassThru
					}
			
					catch {
						Show-InstallationPrompt -Message "ERROR: Unable to mount installer files for installation... Unable to continue." -ButtonRightText 'EXIT' -Icon Information -NoWait
						Exit $mainExitCode
					}
			
					#Get the assigned Drive Letter
					$DriveLetter = (Get-Partition (Get-DiskImage -ImagePath "$envSystemDrive\temp\$appVendor\$appVHDXFile" ).Number | Get-Volume).DriveLetter
			
					# Check if Hotfix File exists before attempting install 
					If (Test-Path $DriveLetter`:\$appHotfixFile\$appFile){

						#Install Hotfix
						Show-InstallationProgress "Installing $appName hotfix $appPatchVersion... This may take some time...  Please Wait..."

						Execute-Process -Path "$DriveLetter`:\$appHotfixFile\$appFile" -Parameters "-SMS !quiet=`"$envSystemDrive\temp\$appVendor\$appHotfixInstall`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'

						# Waiting for Installer installsetup.exe (catches a rare issue where Ansys switches which setup.exe it's using)
						Start-sleep -s 30
			
						Wait-Process -Name installsetup -Timeout 7200
						Wait-Process -Name setup -Timeout 7200
					
						#Adding a wait, since the installsetup.exe sometimes stops and restarts once Disk1 is installed on the desktop. 
						If (Get-Process -Name "installsetup"){
							Write-Log "Execute-Process stopped, but Installer is Still Installing…"
							Wait-Process -Name installsetup -Timeout 7200
						}
					}
			
					#Unmount the VHDX
					Dismount-DiskImage -ImagePath "$envSystemDrive\temp\$appVendor\$appVHDXFile" -Confirm:$false
				}
			
				# Regular install (Since file isn't on UNC drive)
				Else{
			
					# Move files to main drive 
					New-Folder -Path "$envSystemDrive\temp\$appVendor"
					Copy-Item -Path "$dirSupportFiles\*" -Destination "$envSystemDrive\temp\$appVendor" -Recurse
			
					#Mount the VHDX file 
					try {
						Show-InstallationProgress "Mounting $installTitle VHDX files... Please Wait..."
						Mount-DiskImage -ImagePath "$dirFiles\$appVHDXFile" -Access ReadOnly -PassThru
					}
			
					catch {
						Show-InstallationPrompt -Message "ERROR: Unable to mount installer files for installation... Unable to continue." -ButtonRightText 'EXIT' -Icon Information -NoWait
						Exit $mainExitCode
					}
			
					#Get the assigned Drive Letter
					$DriveLetter = (Get-Partition (Get-DiskImage -ImagePath "$dirFiles\$appVHDXFile" ).Number | Get-Volume).DriveLetter

					# Check if Hotfix File exists before attempting install 
					If (Test-Path $DriveLetter`:\$appHotfixFile\$appFile){
			
						#Install Hotfix
						Show-InstallationProgress "Installing $appName hotfix $appPatchVersion... This may take some time...  Please Wait..."
						Execute-Process -Path "$DriveLetter`:\$appHotfixFile\$appFile" -Parameters "-SMS !quiet=`"$envSystemDrive\temp\$appVendor\$appHotfixInstall`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
						# Waiting for Installer installsetup.exe (catches a rare issue where Ansys switches which setup.exe it's using)
						Start-sleep -s 30
			
						Wait-Process -Name installsetup -Timeout 7200
						Wait-Process -Name setup -Timeout 7200
		
						#Adding a wait, since the installsetup.exe sometimes stops and restarts once Disk1 is installed on the desktop. 
						If (Get-Process -Name "installsetup"){
							Write-Log "Execute-Process stopped, but Installer is Still Installing…"
							Wait-Process -Name installsetup -Timeout 7200
						}
					}
				
					#Unmount the VHDX
					Dismount-DiskImage -ImagePath "$dirFiles\$appVHDXFile" -Confirm:$false
				}	
				
				# Remove temp leftover files
				If (Test-Path "$envSystemDrive\temp\$appVendor"){
					Show-InstallationProgress "Removing $appName Installer Files...Please Wait..."
					Remove-Folder -Path "$envSystemDrive\temp\$appVendor" -ContinueOnError $true
				} 
		
				# Refresh the desktop (Make sure reg values are updated)
				Update-Desktop -ContinueOnError $true	
				
				# Get the DisplayVersion Registry value again
				[string]$appDisplayVersion = (Get-InstalledApplication -Name "$appRegName") | select DisplayVersion -expand DisplayVersion
				
				# If current DisplayVersion matches latest patch (Install was successful: Exit the code)
				If ($appDisplayVersion -ge $appPatchVersion) {
					If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "Latest $appVendor $appName $appPatchVersion patch installed... If you have any questions please contact CENG IT Support." -ButtonRightText 'OK' -Icon Information -NoWait }
					Exit-Script -ExitCode 0	
				}
				# Didn't detect DisplayVersion matching than latest patch (Likely failed patching: Completely remove and reinstall)
				Else{
					Show-InstallationProgress "Patch installation likely failed. Preparing for complete reinstallation..."
				}
			}
		}
		
		# Update failed, Older than 17.4, or app not installed (Uninstall old version and continue to install)
		# Search Registry for app and pull ProductGuid
		[array]$appOldUninstalls = (Get-InstalledApplication -Name "$appVendor") | Select-Object -ExpandProperty ProductCode

		Foreach ($appOldUninstall in $appOldUninstalls){
			
			# Trim the value for use later but store in a different variable
			$appOldUninstallTrim = $appOldUninstall.trim('{}')

			If ("$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" | Test-Path){
				Show-InstallationProgress "FOUND InstallShield Path: $envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"
				
				# copy over blanked uninstall.iss file
				Copy-File -Path "$dirSupportFiles\$appUninstallOrCAD" -Destination "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"
				Copy-File -Path "$dirSupportFiles\$appUninstallDLmanager" -Destination "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"
				Copy-File -Path "$dirSupportFiles\$appUninstallOrCAD174" -Destination "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"

				# we need to modify a uninstall.iss file with the ProductGuid of installed version
				Show-InstallationProgress "Generating installshield $appName uninstall file. Please wait..."
		
				# Replace values in the uninstall.iss file
				Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD" -recurse |
				ForEach-Object {
					$c = ($_ | Get-Content) 
					$c = $c -replace "0000","$appOldUninstallTrim"
					[IO.File]::WriteAllText($_.FullName, ($c -join "`r`n"))
				}
				
				# Replace values in the uninstallDLmanager_blank.iss file
				Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallDLmanager" -recurse |
				ForEach-Object {
					$c = ($_ | Get-Content) 
					$c = $c -replace "0000","$appOldUninstallTrim"
					[IO.File]::WriteAllText($_.FullName, ($c -join "`r`n"))
				}
				
				# Replace values in the uninstallOrCAD174_blank.iss file
				Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD174" -recurse |
				ForEach-Object {
					$c = ($_ | Get-Content) 
					$c = $c -replace "0000","$appOldUninstallTrim"
					[IO.File]::WriteAllText($_.FullName, ($c -join "`r`n"))
				}
				
				# Set the old path
				$appOldEXEpath1 = "" + "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" + "\AllegroDownloadManager.exe"
				$appOldEXEpath2 = "" + "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" + "\setup.exe"
				$appOldEXEpath3 = "" + "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" + "\installsetup.exe"
			
				# Then uninstall using premade .iss uninstaller response files 
				If ($appOldEXEpath1 | Test-Path){
					Show-InstallationProgress "Removing Old $appName $ProductVersion Installation....  Please Wait..."

					Execute-Process -Path "$appOldEXEpath1" -Parameters "-s -f1`"$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallDLmanager`" -SMS -uninst" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				
					# Delete leftover InstallShield Files
					If (Test-Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"){
						Remove-Folder -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" -ContinueOnError $true
					}	
				}
				ElseIf ($appOldEXEpath2 | Test-Path){
					Show-InstallationProgress "Removing Old $appName $ProductVersion Installation....  Please Wait..."

					Execute-Process -Path "$appOldEXEpath2" -Parameters "-s -f1`"$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD`" -SMS -uninst" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				
					# Delete leftover InstallShield Files
					If (Test-Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"){
						Remove-Folder -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" -ContinueOnError $true
					}
				}
				ElseIf ($appOldEXEpath3 | Test-Path){
					Show-InstallationProgress "Removing Old $appName $ProductVersion Installation....  Please Wait..."

					Execute-Process -Path "$appOldEXEpath3" -Parameters "-s -f1`"$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD174`" -SMS -uninst" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				
					# Delete leftover InstallShield Files
					If (Test-Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"){
						Remove-Folder -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" -ContinueOnError $true
					}
				}
				
				Else {
					Show-InstallationProgress "Error: EXE Missing for AppCode: $appOldUninstall... Continuing..."
				}	
			
				# Remove any leftover Registry keys
				Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$appOldUninstall" -ContinueOnError $true
			}
		}

		# Remove Leftover Shortcuts
		If (Test-Path "$envCommonStartMenuPrograms\$appVendor"){
			Remove-Folder -Path "$envCommonStartMenuPrograms\$appVendor" -ContinueOnError $true
		}
		
		# Expanded Leftover Shortcut Removal 
		$ShortcutOldStartMenus = Get-ChildItem "$envCommonStartMenuPrograms\$appVendor *"
		ForEach ($ShortcutOldStartMenu in $ShortcutOldStartMenus){
			# if statement to check if variable is null
			If ($ShortcutOldStartMenu | Test-Path){
				Remove-Folder -Path "$ShortcutOldStartMenu" -ContinueOnError $true
			}
		}	

		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$ShortcutOldDesktopPaths = Get-ChildItem "$envCommonDesktop\Programs\$appVendor*"
		ForEach ($ShortcutOldDesktopPath in $ShortcutOldDesktopPaths){
			# if statement to check if variable is null
			If ($ShortcutOldDesktopPath | Test-Path){
				Remove-Folder -Path "$ShortcutOldDesktopPath" -ContinueOnError $true
			}
		}		
		
		# Remove any leftover programFiles
		$appOldProgFiles = Get-ChildItem "$envSystemDrive\$appVendor\SPB*"
		ForEach ($appOldProgFile in $appOldProgFiles){
			$removingFiles = "" + $appOldProgFile
			# if statement to check if variable is null
			If ($removingFiles | Test-Path){
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removingFiles" -ContinueOnError $true
			}
		}
		
		#Remove any leftover folders 
		If (Test-Path "$envSystemDrive\SPB_Data"){
			Remove-Folder -Path "$envSystemDrive\SPB_Data" -ContinueOnError $true
		}
		
		#Remove any leftover folders 
		If (Test-Path "$envSystemDrive\SPB_Data-Silent"){
			Remove-Folder -Path "$envSystemDrive\SPB_Data-Silent" -ContinueOnError $true
		}
		
		# Remove any old ENV keys
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
		
		#Create the main Cadence home folder
		New-Folder -Path "$envSystemDrive\SPB_Data"
		
		# This installer has issues when running on network shares.
		# Check if installer is not on local drive (I.e. C:\ drive). (Since it will fail from a UNC path) 
		If (([System.Uri]$PSScriptRoot).IsUnc){
		
			Show-InstallationProgress "Detected Installer Running via Network UNC Path.. Copying Files Locally...."
			
			# Move file to main drive 
			New-Folder -Path "$envSystemDrive\temp\$appVendor"
			Copy-Item -Path "$dirFiles\*" -Destination "$envSystemDrive\temp\$appVendor" -Recurse
			Copy-Item -Path "$dirSupportFiles\*" -Destination "$envSystemDrive\temp\$appVendor" -Recurse
			
			#Mount the VHDX file 
			try {
				Show-InstallationProgress "Mounting $installTitle VHDX files... Please Wait..."
				Mount-DiskImage -ImagePath "$envSystemDrive\temp\$appVendor\$appVHDXFile" -Access ReadOnly -PassThru
			}
			
			catch {
				Show-InstallationPrompt -Message "ERROR: Unable to Mount Installer VHDX Files for Installation... Unable to Continue." -ButtonRightText 'EXIT' -Icon Information -NoWait
				Exit $mainExitCode
			}
			
			#Get the assigned Drive Letter
			$DriveLetter = (Get-Partition (Get-DiskImage -ImagePath "$envSystemDrive\temp\$appVendor\$appVHDXFile" ).Number | Get-Volume).DriveLetter
			
			Show-InstallationProgress "Installing $installTitle.... This may take some time. Please Wait..."

			# Install base version (Using VHDX)
			Execute-Process -Path "$DriveLetter`:\Disk1\$appFile" -Parameters "-SMS -w !quiet=`"$envSystemDrive\temp\$appVendor\$appInstall`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
			# Waiting for Installer installsetup.exe (catches a rare issue where Ansys switches which setup.exe it's using)
			Start-sleep -s 30
			
			# This installer spawns another process during install, so we need to wait for it to finish before continuing. 
			Show-InstallationProgress "Waiting for $installTitle Installation. This may take some time... Please Wait..."
			Wait-Process -Name installsetup -Timeout 7200
			Wait-Process -Name setup -Timeout 7200
			Wait-Process -Name DownloadManager -Timeout 7200
		
			#Adding a wait, since the installsetup.exe sometimes stops and restarts once Disk1 is installed on the desktop. 
			If (Get-Process -Name "installsetup"){
				Write-Log "Execute-Process stopped, but Installer is Still Running... (Waiting 120 Minutes)"
				Wait-Process -Name installsetup -Timeout 7200
			}
			
			# Refresh the desktop 
			Update-Desktop -ContinueOnError $true
			
			# Check if Hotfix File exists before attempting install 
			If (Test-Path $DriveLetter`:\$appHotfixFile\$appFile){

				#Install Hotfix
				Show-InstallationProgress "Base Install Finished... Applying $appName Hotfix Update $appPatchVersion....  Please Wait..."

				Execute-Process -Path "$DriveLetter`:\$appHotfixFile\$appFile" -Parameters "-SMS !quiet=`"$envSystemDrive\temp\$appVendor\$appHotfixInstall`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'

				# Waiting for Installer installsetup.exe (catches a rare issue where Ansys switches which setup.exe it's using)
				Start-sleep -s 30
			
				Wait-Process -Name installsetup -Timeout 7200
				Wait-Process -Name setup -Timeout 7200
							
				#Adding a wait, since the installsetup.exe sometimes stops and restarts once Disk1 is installed on the desktop. 
				If (Get-Process -Name "installsetup"){
					Write-Log "Execute-Process stopped, but Installer is Still Running... (Waiting 120 Minutes)"
					Wait-Process -Name installsetup -Timeout 7200
				}
			}
			
			#Unmount the VHDX
			Dismount-DiskImage -ImagePath "$envSystemDrive\temp\$appVendor\$appVHDXFile" -Confirm:$false
		}
		# Regular install (Since file isn't on filestore)
		Else{
			
			# Move file to main drive 
			New-Folder -Path "$envSystemDrive\temp\$appVendor"
			Copy-Item -Path "$dirSupportFiles\*" -Destination "$envSystemDrive\temp\$appVendor" -Recurse
			
			#Mount the VHDX file 
			try {
				Show-InstallationProgress "Mounting $installTitle VHDX files... Please Wait..."
				Mount-DiskImage -ImagePath "$dirFiles\$appVHDXFile" -Access ReadOnly -PassThru
			}
			
			catch {
				Show-InstallationPrompt -Message "ERROR: Unable to mount installer files for installation... Unable to continue." -ButtonRightText 'EXIT' -Icon Information -NoWait
				Exit $mainExitCode
			}
			
			#Get the assigned Drive Letter
			$DriveLetter = (Get-Partition (Get-DiskImage -ImagePath "$dirFiles\$appVHDXFile" ).Number | Get-Volume).DriveLetter
			
			Show-InstallationProgress "Installing $appName.... This may take some time. Please Wait..."

			# Install base version (Using VHDX)
			Execute-Process -Path "$DriveLetter`:\Disk1\$appFile" -Parameters "-SMS -w !quiet=`"$envSystemDrive\temp\$appVendor\$appInstall`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
			# Waiting for Installer installsetup.exe (catches a rare issue where Ansys switches which setup.exe it's using)
			Start-sleep -s 30
			
			# This installer spawns another process during install, so we need to wait for it to finish before continuing. 
			Show-InstallationProgress "Waiting for $installTitle Installation. This may take some time... Please Wait..."
			Wait-Process -Name installsetup -Timeout 7200
			Wait-Process -Name setup -Timeout 7200
			Wait-Process -Name DownloadManager -Timeout 7200

			#Adding a wait, since the installsetup.exe sometimes stops and restarts once Disk1 is installed on the desktop. 
			If (Get-Process -Name "installsetup"){
				Write-Log "Execute-Process stopped, but Installer is Still Running... (Waiting 120 Minutes)"
				Wait-Process -Name installsetup -Timeout 7200
			}
			
			# Refresh the desktop 
			Update-Desktop -ContinueOnError $true
			
			# Check if Hotfix File exists before attempting install 
			If (Test-Path $DriveLetter`:\$appHotfixFile\$appFile){
			
				#Install Hotfix
				Show-InstallationProgress "Base Install Finished... Applying $appName Hotfix Update $appPatchVersion....  Please Wait..."

				Execute-Process -Path "$DriveLetter`:\$appHotfixFile\$appFile" -Parameters "-SMS !quiet=`"$envSystemDrive\temp\$appVendor\$appHotfixInstall`"" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
			
				# Waiting for Installer installsetup.exe (catches a rare issue where Ansys switches which setup.exe it's using)
				Start-sleep -s 30
			
				Wait-Process -Name installsetup -Timeout 7200
				Wait-Process -Name setup -Timeout 7200
		
				#Adding a wait, since the installsetup.exe sometimes stops and restarts once Disk1 is installed on the desktop. 
				If (Get-Process -Name "installsetup"){
					Write-Log "Execute-Process stopped, but Installer is Still Running... (Waiting 120 Minutes)"
					Wait-Process -Name installsetup -Timeout 7200
				}
			}
		
			#Unmount the VHDX
			Dismount-DiskImage -ImagePath "$dirFiles\$appVHDXFile" -Confirm:$false
		}

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		
		#Use ForEach loop to remove all icons from any User (Public, Users, etc. Desktop) declared in Variable Declaration...
		ForEach ($appIcon in $appIcons){
			$RemoveDesktopShortcuts = Get-ChildItem "$envSystemDrive\Users\*\Desktop\$appIcon.lnk"
			ForEach ($RemoveDesktopShortcut in $RemoveDesktopShortcuts) {
				If ($RemoveDesktopShortcut | Test-Path) {
					Show-InstallationProgress "Removing $appName Icons ($appIcon)... Please Wait..."
					Remove-File -Path "$RemoveDesktopShortcut" -ContinueOnError $true
				}
			}
		}
		
		#<Post-Installation Code here>
		
		# Set Environment Variable
		Show-InstallationProgress "Setting $appName Environment Variable. Please wait..."
		[System.Environment]::SetEnvironmentVariable("$appLicense", "$appLicenseInfo",[System.EnvironmentVariableTarget]::Machine)
		
		# Remove temp leftover files
		If (Test-Path "$envSystemDrive\temp\$appVendor"){
			Show-InstallationProgress "Removing $appName Installer Files...Please Wait..."
			Remove-Folder -Path "$envSystemDrive\temp\$appVendor" -ContinueOnError $true
		} 
		
		# Add shortcut links to Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$ShortcutDesktopPaths = Get-ChildItem "$envCommonStartMenuPrograms\$appVendor*"
		ForEach ($ShortcutDesktopPath in $ShortcutDesktopPaths){
			Copy-Item -Path "$ShortcutDesktopPath" -Destination "$envCommonDesktop\Programs\$appVendor" -Recurse
		}
		
		# Close any stuck InstallationProgress windows 
		Close-InstallationProgress

		# Refresh the desktop 
		Update-Desktop -ContinueOnError $true

		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "$appVendor $appName $appPatchVersion is now Installed... If you have any questions please contact CENG IT Support." -ButtonRightText 'OK' -Icon Information -NoWait }
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
		
		[array]$appOldUninstalls = (Get-InstalledApplication -Name "$appVendor") | Select-Object -ExpandProperty ProductCode

		Foreach ($appOldUninstall in $appOldUninstalls){
			
			# Trim the value for use later but store in a different variable
			$appOldUninstallTrim = $appOldUninstall.trim('{}')

			If ("$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" | Test-Path){
				Show-InstallationProgress "FOUND InstallShield Path: $envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"
				
				# copy over blanked uninstall.iss file
				Copy-File -Path "$dirSupportFiles\$appUninstallOrCAD" -Destination "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"
				Copy-File -Path "$dirSupportFiles\$appUninstallDLmanager" -Destination "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"
				Copy-File -Path "$dirSupportFiles\$appUninstallOrCAD174" -Destination "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"

				# we need to modify a uninstall.iss file with the ProductGuid of installed version
				Show-InstallationProgress "Generating installshield $appName uninstall file. Please wait..."
		
				# Replace values in the uninstall.iss file
				Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD" -recurse |
				ForEach-Object {
					$c = ($_ | Get-Content) 
					$c = $c -replace "0000","$appOldUninstallTrim"
					[IO.File]::WriteAllText($_.FullName, ($c -join "`r`n"))
				}
				
				# Replace values in the uninstallDLmanager_blank.iss file
				Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallDLmanager" -recurse |
				ForEach-Object {
					$c = ($_ | Get-Content) 
					$c = $c -replace "0000","$appOldUninstallTrim"
					[IO.File]::WriteAllText($_.FullName, ($c -join "`r`n"))
				}
				
				# Replace values in the uninstallOrCAD174_blank.iss file
				Get-ChildItem -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD174" -recurse |
				ForEach-Object {
					$c = ($_ | Get-Content) 
					$c = $c -replace "0000","$appOldUninstallTrim"
					[IO.File]::WriteAllText($_.FullName, ($c -join "`r`n"))
				}
				
				# Set the old path
				$appOldEXEpath1 = "" + "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" + "\AllegroDownloadManager.exe"
				$appOldEXEpath2 = "" + "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" + "\setup.exe"
				$appOldEXEpath3 = "" + "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" + "\installsetup.exe"
			
				# Then uninstall using premade .iss uninstaller response files 
				If ($appOldEXEpath1 | Test-Path){
					Show-InstallationProgress "Removing Old $appName $ProductVersion Installation....  Please Wait..."

					Execute-Process -Path "$appOldEXEpath1" -Parameters "-s -f1`"$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallDLmanager`" -SMS -uninst" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				
					# Delete leftover InstallShield Files
					If (Test-Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"){
						Remove-Folder -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" -ContinueOnError $true
					}	
				}
				ElseIf ($appOldEXEpath2 | Test-Path){
					Show-InstallationProgress "Removing Old $appName $ProductVersion Installation....  Please Wait..."

					Execute-Process -Path "$appOldEXEpath2" -Parameters "-s -f1`"$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD`" -SMS -uninst" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				
					# Delete leftover InstallShield Files
					If (Test-Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"){
						Remove-Folder -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" -ContinueOnError $true
					}
				}
				ElseIf ($appOldEXEpath3 | Test-Path){
					Show-InstallationProgress "Removing Old $appName $ProductVersion Installation....  Please Wait..."

					Execute-Process -Path "$appOldEXEpath3" -Parameters "-s -f1`"$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall\$appUninstallOrCAD174`" -SMS -uninst" -WindowStyle Hidden -ContinueOnError $true -IgnoreExitCodes '*'
				
					# Delete leftover InstallShield Files
					If (Test-Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall"){
						Remove-Folder -Path "$envProgramFilesX86\InstallShield Installation Information\$appOldUninstall" -ContinueOnError $true
					}
				}
				
				Else {
					Show-InstallationProgress "Error: EXE Missing for AppCode: $appOldUninstall... Continuing..."
				}	
			
				# Remove any leftover Registry keys
				Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$appOldUninstall" -ContinueOnError $true
			}
		}

		# Remove Leftover Shortcuts
		If (Test-Path "$envCommonStartMenuPrograms\$appVendor"){
			Remove-Folder -Path "$envCommonStartMenuPrograms\$appVendor" -ContinueOnError $true
		}
		
		# Expanded Leftover Shortcut Removal 
		$ShortcutOldStartMenus = Get-ChildItem "$envCommonStartMenuPrograms\$appVendor *"
		ForEach ($ShortcutOldStartMenu in $ShortcutOldStartMenus){
			# if statement to check if variable is null
			If ($ShortcutOldStartMenu | Test-Path){
				Remove-Folder -Path "$ShortcutOldStartMenu" -ContinueOnError $true
			}
		}	

		# Remove shortcut links from Users->Public->Desktop->Programs folder if it exists (Mainly for lab images)
		$ShortcutOldDesktopPaths = Get-ChildItem "$envCommonDesktop\Programs\$appVendor*"
		ForEach ($ShortcutOldDesktopPath in $ShortcutOldDesktopPaths){
			# if statement to check if variable is null
			If ($ShortcutOldDesktopPath | Test-Path){
				Remove-Folder -Path "$ShortcutOldDesktopPath" -ContinueOnError $true
			}
		}		
		
		# Remove any leftover programFiles
		$appOldProgFiles = Get-ChildItem "$envSystemDrive\$appVendor\SPB*"
		ForEach ($appOldProgFile in $appOldProgFiles) {
			$removingFiles = "" + $appOldProgFile
			# if statement to check if variable is null
			If ($removingFiles | Test-Path){
				Show-InstallationProgress "Removing Old $appName files....  Please Wait..."
				Remove-Folder -Path "$removingFiles" -ContinueOnError $true
			}
		}
		
		#Remove any leftover folders 
		If (Test-Path "$envSystemDrive\SPB_Data"){
			Remove-Folder -Path "$envSystemDrive\SPB_Data" -ContinueOnError $true
		}
		
		#Remove any leftover folders 
		If (Test-Path "$envSystemDrive\SPB_Data-Silent"){
			Remove-Folder -Path "$envSystemDrive\SPB_Data-Silent" -ContinueOnError $true
		}
		
		# Remove any old ENV keys
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
