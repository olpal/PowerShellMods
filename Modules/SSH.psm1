#Written By: AJ O.
##
#Written On: August 9th 2014
###
#Version: 1.1.0

##########################################################
#Name:SSH												 #
#                                                        #
#Description: This module is used to provide ssh access	 #
##########################################################

#Variables for quick use in PowerShell Shell
$Global:SSH = ($MyInvocation.MyCommand.Path.SubString(0,($MyInvocation.MyCommand.Path.LastIndexOf("\"))) + "\Deploy\plink.exe")

#Module Version
#region
#This function is used to check the current version of the SSH module
function Get-VersionSSH{
	#The Current version of the Module addin pack
	[String] $ModVersion = "SSH Module Version 1.1.0"
	#Return the Current version of the module pack
	Return $ModVersion
}
#endregion

#SSH Functions
#region

#This function is used to open an interactive session to a remote host using the SSH protocol
Function Open-RemoteHost {
	Param([Parameter(Mandatory=$true,HelpMessage="The name of the host to open a connection to")][String]$HostID,
			[Parameter(Mandatory=$true,HelpMessage="The name of the user account to use when opening a connection")][String]$Username,
			[Parameter(Mandatory=$false,HelpMessage="The full path to the plink executable")][String]$Exe=$Global:SSH)
	
	#Create the command
	$Command = ("& '{0}' {1}@{2}" -f $Exe,$Username,$HostID)
	#Invoke the command
	Invoke-Expression -Command $Command
}

#endregion
