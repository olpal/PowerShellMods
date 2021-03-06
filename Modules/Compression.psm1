#Written By: AJ O.
##
#Written On: August 9th 2014
###
#Version: 1.1.0

##########################################################
#Name:CompressionPack									 #
#                                                        #
#Description: This module is used to provide compression #
# and decompression functionality through the use of the #
# 7Zip executable										 #
##########################################################

#Variables for quick use in PowerShell Shell
$Global:7ZIP = ($MyInvocation.MyCommand.Path.SubString(0,($MyInvocation.MyCommand.Path.LastIndexOf("\"))) + "\Deploy\7za.exe")

#~Module Control 
#Region
#This function is used to check the current version of the compression module
function Get-VersionCompression{
	#The Current version of the Module addin pack
	[String] $ModVersion = "Compression Module Version 1.1.0"
	#Return the Current version of the module pack
	Return $ModVersion
}
#endregion

#Zip/Unzip functions
#region

#This function is used to compress a file or files
#The function a single file or a list of files, 7zip executable path and destination archive path
#as required variables. The function also allows for the use of custom option strings and password protection.
function New-Compress{
	Param([Parameter(Mandatory=$true, HelpMessage="List of files to compress.")][Array]$FileList,
			[Parameter(Mandatory=$true, HelpMessage="The archive to add files to.")][String]$DestArchive,
			[Parameter(Mandatory=$false, HelpMessage="Password for the archive if required")][String]$Password,
			[Parameter(Mandatory=$false, HelpMessage="Options string to use instead,")][String]$Options,
			[Parameter(Mandatory=$true, HelpMessage="Full path to 7Zip executable")][String]$Exe)
		
	if(Test-Path -Path $Exe){
		#If the destination archive doesn't end in .zip
		if((-not($DestArchive.endsWith(".zip"))) -and (-not($DestArchive.endsWith(".Zip")))){$DestArchive += ".zip"}
		#Command to execute
		$Command = "& '" + $Exe + "' "
		if($Options){
			#Assign $options to command
			$Command += $Options 
		}
		else{
			#If password is present add it to the command string
			if($Password){$Command += ("-p" + "{0}")}
			#create the options string
			$Command += " -tzip a "
			#add file names
			$Command += (" '{0}' " -f $DestArchive)
			#Foreach file in the list
			foreach($File in $FileList){
				#Add the file to command
				$Command += (" '{0}' " -f $File)
			}
		}
		new-event -SourceIdentifier "New-Compress" -MessageData ("Begining compression with the following command: {0}" -f $Command) | out-null
		#If password is present add it into the command string
		#This is done twice to prevent it from being written to the log file in the above event
		if($Password){$Command = $Command -f $Password}
		#Results of the command
		[Array]$Results = Invoke-Expression -Command ($Command)
		#For each line in the results array
		foreach($Line in $Results){
			#If the line is greater than 0
			if($Line.length -gt 0){new-event -SourceIdentifier "Compress" -MessageData $Line | out-null}
		}
		if($LASTEXITCODE -eq 0){return $true}
		else{return $false}
	}
	else{
		new-event -SourceIdentifier "New-Compress" -MessageData ("FAIL:7zip executable was not found.") | out-null
	}
}

#This function is used to decompress a file or files
#The function a single file or a list of files, 7zip executable path and destination archive path
#as required variables. The function also allows for the use of custom option strings and password decryption.
Function New-Decompress{
	Param([Parameter(Mandatory=$true, HelpMessage="Path of file to decompress.")][Array]$FilePath,
			[Parameter(Mandatory=$true, HelpMessage="Path to extract files to..")][String]$DestPath,
			[Parameter(Mandatory=$false, HelpMessage="Password for the archive if present")][String]$Password,
			[Parameter(Mandatory=$false, HelpMessage="Options string to use instead,")][String]$Options,
			[Parameter(Mandatory=$true, HelpMessage="Full path to 7Zip executable")][String]$Exe)
	
	if(Test-Path -Path $Exe){
		#Command to execute
		$Command = "& '" + $Exe + "' "
		if($Options){
			#Assign $options to command
			$Command += $Options 
		}
		else{
			#create the options string
			$Command += " e -y `"-o" + $DestPath + "`" "
			#If password is present add it to the command string
			if($Password){$Command += ("-p" + $Password + " ")}
			#add file names
			$Command += "'" + $FilePath + "'"
		}
		new-event -SourceIdentifier "New-Decompress" -MessageData ("Begining decompression with the following command: {0}" -f $Command) | out-null
		#Results of the command
		[Array]$Results = Invoke-Expression -Command ($Command)
		#For each line in the results array
		foreach($Line in $Results){
			#If the line is greater than 0
			if($Line.length -gt 0){new-event -SourceIdentifier "Decompress" -MessageData $Line | out-null}
		}
		if($LASTEXITCODE -eq 0){return $true}
		else{return $false}
	}
	else{
		new-event -SourceIdentifier "New-Decompress" -MessageData ("FAIL:7zip executable was not found.") | out-null
	}	
}

#endregion