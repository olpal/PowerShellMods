#Written By: AJ O.
##
#Written On: August 9th 2014
###
#Version: 1.1.0

##########################################################
#Name:FileTransfer										 #
#                                                        #
#Description: This module is used to provide access to	 #
# the Upload/Download functionality through the use of   # 
# the Winscp executable 							 	 #
##########################################################

#Variables for quick use in PowerShell Shell
$Global:WINSCP = ($MyInvocation.MyCommand.Path.SubString(0,($MyInvocation.MyCommand.Path.LastIndexOf("\"))) + "\Deploy\WinSCP.exe")

#Module Version
#region
#This function is used to check the current version of the File transfer module
function Get-VersionFileTransfer{
	#The Current version of the Module addin pack
	[String] $ModVersion = "FileTransfer Module Version 1.1.0"
	#Return the Current version of the module pack
	Return $ModVersion
}
#endregion

#FTP Functions
#region

#This function sets up a connection to an ftp server.
#The function takes numerous required parameters relating to Host, Username and protocol.
#The function also takes a Password, Port and SSH key as non mandatory parameters.
#Note SSH key must be provided if a sftp connection is to be used.
function New-ConnectOptions{
	Param([Parameter(Mandatory=$true, HelpMessage="This is the host address.")][String]$Host,
		[Parameter(Mandatory=$true, HelpMessage="This is the protocol to use sftp or ftp.")][ValidateSet("sftp","ftp")][String]$Protocol,
		[Parameter(Mandatory=$true, HelpMessage="The username to use to log in to the server.")][String]$Username,
		[Parameter(Mandatory=$false, HelpMessage="The password associated with the username.")][String]$Password,
		[Parameter(Mandatory=$false, HelpMessage="SSH fingerprint of the host - Required if using SSH")][String]$SshHostkey,
		[Parameter(Mandatory=$false, HelpMessage="Port number if different than the default protocol port represented by 0.")][int]$Port=0,
		[Parameter(Mandatory=$true, HelpMessage="The full path to the WinSCP Dll")][String]$Dll)
	
	#Loads the WinSCP library - If this is a network location full trust must be granted if using .Net 4 or above
	[System.Reflection.Assembly]::LoadFrom($Dll) | Out-Null
	
	try{
		New-Event -SourceIdentifier "New-ConnectOptions" -MessageData ("Creating Session object...") | Out-Null
		#Session Options
		$SessOpt = New-Object WinSCP.SessionOptions
		#Set the host
		$SessOpt.HostName = $Host
		#Set Username and password
		$SessOpt.UserName = $Username
		$SessOpt.Password = $Password
		#Set the port
		$SessOpt.PortNumber = $Port
		
		#Set the protocol
		if($Protocol -eq "ftp"){$SessOpt.Protocol = [WinScp.Protocol]::Ftp}
		else{
			#Set protocol to sftp
			$SessOpt.Protocol = [WinScp.Protocol]::Sftp
			#Set the SSH fingerprint
			if($SshHostkey){$SessOpt.SshHostKey = $SshHostkey}
			else{
			New-Event -SourceIdentifier "New-ConnectOptions" -MessageData ("FAIL:No SSH key provided. SSH key is mandatory for sftp connections.") | Out-Null}
		}
		New-Event -SourceIdentifier "New-ConnectOptions" -MessageData  ("SUCCESS:Session object creation sucessfull.")  | Out-Null
		return [WinSCP.SessionOptions]$SessOpt 
	}
	catch{
		New-Event -SourceIdentifier "Error" -MessageData  ("FAIL:Session object creation encountered and error.")  | Out-Null
		New-Event -SourceIdentifier "Error" -MessageData  $_.Exception.Message  | Out-Null
		if($Error){New-Event -SourceIdentifier "Error" -MessageData  $Error | Out-Null  } 
		break
	}
}

#This function downloads a file from remote server. The function takes 4 mandatory
#parameters: The full path to the remote file(s) - this can be provided as a String or an
#array for multiple files, the local path to save the file to (including a file name saves
#the file(s) as that name otherwise end the path with a \ for a directory.
#login directory on the server, a Transfer Options object and Session object.
function Get-DownloadFile{
Param([Parameter(Mandatory=$true, HelpMessage="A SessionOptions object with attributes already defined.")][WinSCP.SessionOptions]$Options,
	[Parameter(Mandatory=$true, HelpMessage="Path of the file(s) to download.")][Array]$Remote,
	[Parameter(Mandatory=$true, HelpMessage="Local path to save files to.")][String]$Local,
	[Parameter(Mandatory=$true, HelpMessage="Transfer options object.")][WinSCP.TransferOptions]$TransOpt,
	[Parameter(Mandatory=$false, HelpMessage="If a wildcard filename is specified, don't check for the files existance because it is not possible")][boolean]$Wild=$false,
	[Parameter(Mandatory=$false, HelpMessage="Command to execute on the server")][String]$Command,
	[Parameter(Mandatory=$true, HelpMessage="The full path to the WinSCP Dll")][String]$Dll)
	
	#Loads the WinSCP library - If this is a network location full trust must be granted if using .Net 4 or above
	[System.Reflection.Assembly]::LoadFrom($Dll) | Out-Null

	try{
		New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Download process begining...")  | Out-Null
		#Array of files to upload
		$ToDown = @();$ToDown += $Remote
		
		New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Opening Connection to {0}" -f $Options.HostName)  | Out-Null
		#New session
		$Session = New-Object WinScp.Session
		
		#Connect to the host
		$Session.Open($Options)
		New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Connection to {0} now open." -f $Options.HostName)  | Out-Null
		
		#if a command exists execute it
		if($Command){$Session.ExecuteCommand($Command)}
		#Transfer the files
		foreach($FileDn in $ToDown){
			New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Checking for existance of {0}" -f $FileDn)  | Out-Null
			#If the file exists
			if(($Wild -eq $true) -or ($Session.FileExists($FileDn))){
				#if not a wildcard 
				if($Wild -eq $false){ 
					New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Found {0}" -f $FileDn)  | Out-Null
					New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Downloading {0}" -f $FileDn)  | Out-Null
				}
				else{
					New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Attempting to download wild card file name {0}" -f $FileDn)  | Out-Null
				}	
				#Transfer the file and get the results
				$TranResult = $Session.GetFiles($FileDn, $Local, $false, $TransOpt)
				#Check for errors
				$TranResult.Check()
				#Write Completed message
				Foreach($Tran in $TranResult.Transfers){
					#Write message
					New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("SUCCESS:" + $FileDn + " to " + $Local + " succeeded")  | Out-Null
				}
			}
			else{
				New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("FAIL:File not Found {0}" -f $FileDn) | Out-Null
			}
		}
		New-Event -SourceIdentifier "Get-DownloadFile" -MessageData  ("Download process complete.") | Out-Null
	}
	catch{
		New-Event -SourceIdentifier "Error" -MessageData  ("FAIL:encountered an error, see log for details.")  | Out-Null
		New-Event -SourceIdentifier "Error" -MessageData  $_.Exception.Message  | Out-Null
		if($TranResult){New-Event -SourceIdentifier "Error" -MessageData  ($TranResult.get_Failures()) | Out-Null}
		if($Error){New-Event -SourceIdentifier "Error" -MessageData  $Error | Out-Null }
		break
	}
	finally{
		#Dispose of the session
		$Session.Dispose()
	}
}

#This function creates a transfer options object and returns
#it to the invoking method. The function takes one parameter
#which is the transfer mode (Binary, ASCII, or Auto). The function returns
#a winscp.Transferoptions object.
function New-TransferOptions{
	Param([Parameter(Mandatory=$true, HelpMessage="Transfer Mode (Binary, ASCII or Auto)")][ValidateSet("Binary","ASCII","Auto")][String]$Mode,
	[Parameter(Mandatory=$true, HelpMessage="The full path to the WinSCP Dll")][String]$Dll)
	
	#Loads the WinSCP library - If this is a network location full trust must be granted if using .Net 4 or above
	[System.Reflection.Assembly]::LoadFrom($Dll) | Out-Null
	
	try{
		New-Event -SourceIdentifier "New-TransferOptions" -MessageData  ("Transfer options object creation starting...")  | Out-Null
		#Create a new Transfer options object
		$TranOpt = New-Object WinSCP.TransferOptions
		
		#Assign the correct mode
		if($Mode -eq "ASCII"){$TranOpt.TransferMode = [WinSCP.TransferMode]::Ascii}
		elseif($Mode -eq "Binary"){$TranOpt.TransferMode = [WinSCP.TransferMode]::Binary}
		else{$TranOpt.TransferMode = [WinSCP.TransferMode]::Automatic}
		
		New-Event -SourceIdentifier "New-TransferOptions" -MessageData  ("SUCCESS:Transfer options object creation sucessfull.")  | Out-Null
		#Return the options
		return [WinSCP.TransferOptions]$TranOpt
	}
	catch{
		New-Event -SourceIdentifier "Error" -MessageData  ("FAIL:Transfer options object creation failed.")  | Out-Null
		New-Event -SourceIdentifier "Error" -MessageData  $_.Exception.Message  | Out-Null
		if($Error){New-Event -SourceIdentifier "Error" -MessageData  $Error | Out-Null } 
	}
}

#This function uploads a file to a remote server. The function takes 4 mandatory
#parameters: The full path to the local file(s) - this can be provided as a String or an
#array, the remote path to upload the file to relative from the root login directory
#on the server, a Transfer Options object and Session object.
function Push-UploadFile{
Param([Parameter(Mandatory=$true, HelpMessage="A SessionOptions object with attributes already defined.")][WinSCP.SessionOptions]$Options,
	[Parameter(Mandatory=$true, HelpMessage="Path of the file(s) to upload.")][Object]$Local,
	[Parameter(Mandatory=$true, HelpMessage="Path on the remote server to upload to.")][String]$Remote,
	[Parameter(Mandatory=$true, HelpMessage="Transfer options object.")][WinSCP.TransferOptions]$TransOpt,
	[Parameter(Mandatory=$true, HelpMessage="The full path to the WinSCP Dll")][String]$Dll)
	
	#Loads the WinSCP library - If this is a network location full trust must be granted if using .Net 4 or above
	[System.Reflection.Assembly]::LoadFrom($Dll) | Out-Null

	try{
		New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("Upload process begining...") | Out-Null
		#Array of files to upload
		$ToUpload = @();$ToUpload += $Local
		New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("Opening Connection to {0}" -f $Options.HostName) | Out-Null 
		#New session
		$Session = New-Object WinScp.Session
		#Connect to the host
		$Session.Open($Options)
		New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("Connection to {0} now open." -f $Options.HostName) | Out-Null 
		
		#Transfer the files
		foreach($FileUp in $ToUpload){
			New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("Checking for existance of {0}" -f $FileUp)  | Out-Null
			#If the file exists
			if(Test-path -Path $FileUp){
				New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("Found {0}" -f $FileUp)  | Out-Null
				New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("Uploading {0} ..." -f $FileUp)  | Out-Null
				#Transfer the file and get the results
				$TranResult = $Session.PutFiles($FileUp, $Remote, $false, $TransOpt) 
				#Check for errors
				$TranResult.Check()
				#Write Completed message
				Foreach($Tran in $TranResult.Transfers){
					#Write message
					New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("SUCCESS:Upload of " + $FileUp + " to " + $Remote + " succeeded")  | Out-Null
				}
			}
			else{
				New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("FAIL:File not Found {0}" -f $FileUp)  | Out-Null
			}
		}
		New-Event -SourceIdentifier "Push-UploadFile" -MessageData  ("Upload process complete.")  | Out-Null
	}
	catch{
		New-Event -SourceIdentifier "Error" -MessageData  ("FAIL:Upload process encountered an error, see log for details.")  | Out-Null
		New-Event -SourceIdentifier "Error" -MessageData  $_.Exception.Message  | Out-Null
		if($TranResult){New-Event -SourceIdentifier "Error" -MessageData  ($TranResult.get_Failures()) | Out-Null}
		if($Error){New-Event -SourceIdentifier "Error" -MessageData  $Error | Out-Null}
		break
	}
	finally{
		#Dispose of the session
		$Session.Dispose()
	}
}

#endregion