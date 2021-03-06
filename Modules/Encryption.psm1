#Written By: AJ O.
##
#Written On: August 9th 2014
###
#Version: 1.1.2

##########################################################
#Name:Encryption										 #
#                                                        #
#Description: This module is used to provide access to	 #
# the encryption/decryption functionality through the	 #
# use of the gpg.exe executable and supporting files	 #
##########################################################

#Variables for quick use in PowerShell Shell
$Global:GPG = ($MyInvocation.MyCommand.Path.SubString(0,($MyInvocation.MyCommand.Path.LastIndexOf("\"))) + "\Deploy\gpg.exe")
$Script:GPGHome = $Env:APPDATA + "\gnupg\"

#~Module Version 
#Region
#This function is used to check the current version of the module pack.
#The function returns the version string variable stored in CCSModVerions
function Get-VersionEncryption{
	#The Current version of the Module addin pack
	[String] $ModVersion = "Encryption Module Addon 1.1.2"
	#Return the Current version of the module pack
	Return $ModVersion
}
#endregion

#Encrypt/Decrypt Functions
#region

#This function creates a GUI window that is used to
#enter a GPG passphrase. A blank file is then signed with the passphrase
#to test its validity. If it fails the results are returned to the window.
function Get-Passphrase{
	Param([Parameter(Mandatory=$false, HelpMessage="This is the 8 digit key ID of a private key to use in decryption.")][String]$KeyIn,
		  [Parameter(Mandatory=$false, HelpMessage="This is the passphrase for the supplied 8 digit private key ID in KeyID.")][String]$PassPhrase,
		  [Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG)
	
	if(Test-Path -Path $Exe){
		#Hashtable of keyids and names as present in the private keyring
		$PgpTab = @{}
		
		new-event -SourceIdentifier "Get-Passphrase" -MessageData ("Querying Secret key list") | out-null
		#list of secret keys currently available
		[Array]$SecretKeys = Invoke-Expression -Command ("& '{0}' --homedir='{1}' --list-secret-keys" -f $Exe,$Script:GPGHome) 
		
		#If the array is not null
		if($SecretKeys -ne $null){
			#Foreach line in the $SecretKeys array
			foreach($Line in $SecretKeys){
				#If the line starts with sec
				if($Line.StartsWith("sec")){
					#Create a substring of key id
					$KeyId = $Line.Substring($Line.IndexOf("/")+1,8)
					#Create user id 
					$UserId = ($SecretKeys[([System.Array]::IndexOf($SecretKeys,$Line)+1)].Substring(3)).Trim()
					#Add both values to the hashtable
					$PgpTab.Add($UserId,$KeyId)
				}
			}
			new-event -SourceIdentifier "Get-Passphrase" -MessageData ("Checking for correct passphrase") | out-null
			#Variable to represent result of passphrase test
			$PassResult = ""
			#Variable representing first pass
			$Passed = $false
			#While $passresult contains bad passphrase or is blank
			while(($PassResult.length -eq 0) -or ($PassResult.Contains("bad passphrase") -or $LASTEXITCODE -ne 0)){
				#Credential object to prompt for password
				$Cred = $null
				#Command to run
				$Command = "echo test | {0} --homedir='{1}' --no-use-agent --batch --passphrase {2} --local-user {3} -sa 2>&1"
				#If the passphrase is not blank and Passresult length is 0
				if((($KeyIn) -and ($PassPhrase)) -and ($PassResult.length -eq 0)){
					#Get current passphrase credentials
					$Cred = New-Object System.Management.Automation.PSCredential($KeyIn,(ConvertTo-SecureString -String $PassPhrase -AsPlainText -Force))
				}
				else{
					#Get current passphrase credentials
					$UserPass = Show-DrawPassPhrase -UserInfo $PgpTab.Keys -Failed $Passed
					#If userpass is not null
					if(($UserPass[0].length -gt 0) -and ($UserPass[1].length -gt 0)){
						#Assign the key to KeyIn
						$Cred = New-Object System.Management.Automation.PSCredential($PgpTab.get_Item($UserPass[0]),$UserPass[1])
					}
					else{
						break
					}
				}
				#Results of the passphrase test
				[String]$PassResult = Invoke-Expression -Command ($Command -f ("& '" + $Exe + "' "),$Script:GPGHome,($Cred.GetNetworkCredential()).PassWord,$Cred.UserName)  
				new-event -SourceIdentifier "Get-Passphrase" -MessageData ($PassResult) | out-null
				#set passed - representing first pass - to true
				$Passed = $true
			}
			#Return the Credential object
			return $Cred
		}
		else{
			new-event -SourceIdentifier "Error" -MessageData ("FAIL:Unable to locate GPG Keyring in home directory {0}" -f $Script:GPGHome) | out-null
		}
	}
	else{
		new-event -SourceIdentifier "Error" -MessageData ("FAIL:Unable to locate GPG Executable {0}" -f $Exe) | out-null
	}
}

#This function is used to decrypt a PGP file using GPG.
#The function takes the file path, the GPG executable and the passphrase as 
#required variables. The function also use of a full options string through the 
#optional options parameter.
function Unlock-Decrypt{
	Param([Parameter(Mandatory=$true, HelpMessage="This is the full path of the file to decrypt.")][String]$FilePath,
		  [Parameter(Mandatory=$true, HelpMessage="This is a credential object with username set to a 8 digit key ID and password as the corresponding passphrase.")][Management.Automation.PSCredential]$Credentials,
		  [Parameter(Mandatory=$false, HelpMessage="This is a string of option commands. Do not include the decrypt command.")][String]$Options,
		  [Parameter(Mandatory=$false, HelpMessage="Optional output file name")][String]$OutFile,
		  [Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG)
	
	if(Test-Path -Path $Exe){
		#If the file to decrypt exists
		if(Test-Path -Path $FilePath){
			new-event -SourceIdentifier "Unlock-Decrypt" -MessageData ("Begining Decryption of {0}" -f $FilePath) | out-null
			
			#Options String
			$OptionFinal = ""
			#If passed in options exist
			if($Options){
				#Add Options String
				$OptionFinal = ($Options + " --decrypt " + $FilePath)
				#Construct the command
				$Command = $Exe + " " + $OptionFinal
				new-event -SourceIdentifier "Unlock-Decrypt" -MessageData ("Decrypting with the following command string: {0}" -f $Command) | out-null
				#Execute the Decryption process
				[String]$output = Invoke-Expression -Command ($Command)
				#Create new event from the output
				new-event -SourceIdentifier "Unlock-Decrypt" -MessageData $output | out-null
			}
			else{
				#Assign the Options String with four spaces for Executable,Output, PassPhrase and File
				$Command = "& '{0}' --homedir='{1}' --output `"{2}`" --batch --passphrase {3} --decrypt `"{4}`" 2>&1"
				
				#If outfile value is not present or it ends with a \
				if(-not($OutFile) -or ($OutFile.EndsWith("\"))){
					#Assign the path to the outfile variable
					$OutFile = $FilePath.Substring(0,($Local:FilePath.LastIndexOf(".")))
				}
				
				new-event -SourceIdentifier "Unlock-Decrypt" -MessageData ("Decrypting with the following command string: {0}" -f $Command) | out-null
				#Execute the Decryption process
				[String]$output = Invoke-Expression -Command ($Command -f $Exe,$Script:GPGHome,$OutFile,($Credentials.GetNetworkCredential()).PassWord,$FilePath)
				#Create new event from the output
				new-event -SourceIdentifier "Unlock-Decrypt" -MessageData $output  | out-null
			}
			
			#If the command completed sucessfully
			if($LASTEXITCODE -eq 0){
				#Get the type of file created
				$Rename = $OutFile + (Find-FileType -FilePath $OutFile)
				#Rename the file with the extension
				Rename-Item -Path $OutFile -NewName $Rename -Force
				new-event -SourceIdentifier "Unlock-Decrypt" -MessageData ("{0} was successfully decrypted to {1}." -f $FilePath, $Rename) | out-null
				#Return the $Rename path
				return $Rename
			}
			else{
				new-event -SourceIdentifier "Error" -MessageData ("FAIL:Decryption failed: LASTEXITCODE=" + $LASTEXITCODE + ". Check log file for additional details. Breaking now...") | out-null
				break
			}
		}
		else{
			new-event -SourceIdentifier "Error" -MessageData ("FAIL:Unable to locate file {0}" -f $FilePath) | out-null
		}
	}
	else{
		new-event -SourceIdentifier "Error" -MessageData ("FAIL:Unable to locate GPG Executable {0}" -f $Exe) | out-null
	}
}

#This function is used to encrypt a file using the supplied GPG executable
#and encryption key. An optional signing key or options string can also be provided.
function Lock-Encrypt{
	Param([Parameter(Mandatory=$true, HelpMessage="This is the full path of the file to encrypt.")][String]$FilePath,
		  [Parameter(Mandatory=$true, HelpMessage="This is the key to use for encryption; KeyId's should be used rather than names.")][String]$EncryptKey,
		  [Parameter(Mandatory=$false, HelpMessage="This is the key to use for signing purposes.")] [String]$SignKey,
		  [Parameter(Mandatory=$false, HelpMessage="This is a string of option commands. Do not include the Encrypt and Sign commands")][String]$Options,
		  [Parameter(Mandatory=$false, HelpMessage="Optional output file name")][String]$OutFile,
		  [Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG)
	
	if(Test-Path -Path $Exe){
		#If the file to decrypt exists
		if(Test-Path -Path $FilePath){
			New-Event -SourceIdentifier "Lock-Encrypt" -MessageData ("Encryption begining...") | Out-Null
			#Options String
			$OptionFinal = ""

			#If outfile value is present add to the options string
			if($OutFile){ $OptionFinal += (" -o '" + $OutFile + "' ")}
			
			#If passed in options exist
			if($Options){
				#Assign passed in Options String to options final variable
				$OptionFinal = $Options + " -r " + $EncryptKey + " -e " + $FilePath
			}
			else{
				#Add Options String
				$OptionFinal += "--homedir='{0}' --batch --pgp8 --trust-model Always -q -r " + $EncryptKey + " -e '" + $FilePath + "' "
			}
			
			#If sign key is present add to the options string
			if($SignKey){ $OptionFinal += (" -s " + $SignKey) }
			
			#Add the out command option that redirects errors to the Standard cmd varaiable
			$OptionFinal += " 2>&1"
			#Construct the command
			$Command = "& '" + $Exe + "' " + ($OptionFinal -f $Script:GPGHome)
			New-Event -SourceIdentifier "Lock-Encrypt" -MessageData ("Encrypting with the following command string: {0}" -f $Command) | Out-Null
			#Execute the encryption process
			[String]$output = Invoke-Expression $Command
			#Create new event from the output
			New-Event -SourceIdentifier "Lock-Encrypt" -MessageData ($output) | out-null
			#If the command completed sucessfully
			if($LASTEXITCODE -eq 0){
				New-Event -SourceIdentifier "Lock-Encrypt" -MessageData ($FilePath + " was successfully encrypted.") | out-null
			}
			else{
				if($Error){new-event -SourceIdentifier "Error" -MessageData $Error | out-null}
				new-event -SourceIdentifier "Error" -MessageData ("FAIL:Encryption failed: LASTEXITCODE=" + $LASTEXITCODE + ". Check log file for additional details. Breaking now...") | out-null
				break
			}
		}
		else{
			new-event -SourceIdentifier "Error" -MessageData ("FAIL:Unable to locate file {0}" -f $FilePath) | out-null
		}
	}
	else{
		new-event -SourceIdentifier "Error" -MessageData ("FAIL:Unable to locate GPG Executable {0}" -f $Exe) | out-null
	}	  
}

#This function is used to import keys into the gpg keyring
function Import-Keys{
	Param([Parameter(Mandatory=$false, HelpMessage="Path to public key ring.")][String]$PubKey,
		  [Parameter(Mandatory=$false, HelpMessage="Path to private key ring")][String]$PrivKey,
		  [Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG)

	
	#If the GPG executable exists
	if(Test-Path -Path $Exe){
		#if the pubkeyring file exists
		if(($PubKey.Length -gt 0) -and (Test-Path -Path $PubKey)){
			#Import key ring
			[String]$output = Invoke-Expression -Command ("& '{0}' --homedir='{1}' --import `"{2}`" 2>&1" -f $Exe,$Script:GPGHome,$PubKey)
			Out-Host -InputObject  $output
			Out-Host -InputObject ("SUCCESS:Import of keys from {0} succeeded" -f $PubKey) | out-null
		}
		else{
			Out-Host -InputObject  ("FAIL:Unable to Import keys to keyring - No Public keyring file found at " + $PubKey) | out-null
		}
		if(($PrivKey.Length -gt 0) -and (Test-Path -Path $PrivKey)){
			#Import key ring
			[String]$output = Invoke-Expression -Command ("& '{0}' --homedir='{1}' --import `"{2}`" 2>&1" -f $Exe,$Script:GPGHome,$PrivKey)
			Out-Host -InputObject  $output
			Out-Host -InputObject  ("SUCCESS:Import of keys from {0} succeeded" -f $PrivKey) | out-null
		}
		else{
			Out-Host -InputObject  ("FAIL:Unable to Import keys to keyring - No Private keyring file found at " + $PrivKey) | out-null
		}
	}
	else{
		Out-Host -InputObject  ("FAIL:Unable to find executable {0}" -f $Exe) | out-null
		
	}
}

#This function is used to list publickey information stored in the gpg keyring
function Show-Keys{
	Param([Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG)

	#If the GPG executable exists
	if(Test-Path -Path $Exe){
		#Show the keys in the current keyring
		Invoke-Expression -Command ("& '{0}' --homedir='{1}' --list-keys" -f $Exe,$Script:GPGHome)	
	}
}

#This function is used to list privatekey information stored in the gpg keyring
function Show-SecretKeys{
	Param([Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG)

	#If the GPG executable exists
	if(Test-Path -Path ($Exe.ToString())){
		#Show the keys in the current keyring
		Invoke-Expression -Command ("& '{0}' --homedir='{1}' --list-secret-keys" -f $Exe,$Script:GPGHome)		
	}
}

#This function is used to delete publickey information stored in the gpg keyring
function Remove-Key{
	Param([Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG,
			[Parameter(Mandatory=$true, HelpMessage="8 digit ID of the public key to delete")][String]$KeyID)

	#If the GPG executable exists
	if(Test-Path -Path $Exe){
		#Show the keys in the current keyring
		Invoke-Expression -Command ("& '{0}' --homedir='{1}' --delete-key {2}" -f $Exe,$Script:GPGHome,$KeyID)	
	}
}

#This function is used to delete privatekey information stored in the gpg keyring
function Remove-SecretKey{
	Param([Parameter(Mandatory=$false, HelpMessage="The full path to the gpg exe")][String]$Exe=$Global:GPG,
			[Parameter(Mandatory=$true, HelpMessage="8 digit ID of the private key to delete")][String]$KeyID)
	
	#If the GPG executable exists
	if(Test-Path -Path ($Exe.ToString())){
		#Show the keys in the current keyring
		Invoke-Expression -Command ("& '{0}' --homedir='{1}' --delete-secret-key {2}" -f $Exe,$Script:GPGHome,$KeyID)	
	}
}

#This function is designed to provide a user interface for
#the entering of a pass phrase and selection of user from a list.
#The function takes an array of users as a mandatory parameter and
#returns a user string and passphrase secure string.
Function Show-DrawPassPhrase{
	Param([Parameter(Mandatory=$true, HelpMessage="A list of users for to populate the combo box with")][Array]$UserInfo,
		[Parameter(Mandatory=$false, HelpMessage="Boolean representing failed attempt.")][boolean]$Failed)
	
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	
	#User String variable to return
	$User = "";
	#Secure string to return
	$Password = ""
	
	#Label For information
	$FailLabel = New-Object System.Windows.Forms.Label
	$FailLabel.Text = "Passphrase Test Failed: Please try again."
	$FailLabel.Location = New-Object System.Drawing.Point(50,15)
	$FailLabel.Size = new-object System.Drawing.Size(300,15)
	$FailLabel.ForeColor = [System.Drawing.Color]::Red
	
	#Label For information
	$InfoLabel = New-Object System.Windows.Forms.Label
	$InfoLabel.Text = "Select a user from the list:"
	$InfoLabel.Location = New-Object System.Drawing.Point(50,30)
	$InfoLabel.Size = new-object System.Drawing.Size(200,15)

	#Label For information
	$PassLabel = New-Object System.Windows.Forms.Label
	$PassLabel.Text = "Enter the passphrase:"
	$PassLabel.Location = New-Object System.Drawing.Point(50,80)
	$PassLabel.Size = new-object System.Drawing.Size(200,15)

	#List box to hold users
	$UsersBox = New-Object System.Windows.Forms.ComboBox
	$UsersBox.Size = New-Object Drawing.Size(300,55)
	$UsersBox.Location = New-Object System.Drawing.Point(50,50)
	$UsersBox.items.AddRange($UserInfo)
	$UsersBox.SelectedIndex = 0
	$UsersBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

	#TextBox for pass phrase
	$PassPhraseBox = New-Object System.Windows.Forms.TextBox
	$PassPhraseBox.Size = New-Object Drawing.Size(300,55)
	$PassPhraseBox.Location = New-Object System.Drawing.Point(50,100)
	$PassPhraseBox.PasswordChar = "*"
	
	#Ok Button
	$OkButton = New-Object System.Windows.Forms.Button
	$OkButton.Text = "OK"
	$OkButton.Size = New-Object Drawing.Size(65,25)
	$OkButton.Location = New-Object System.Drawing.Point(120,130)
	$OkButton.add_Click({$Password = (Convertto-secureString -String $PassPhraseBox.Text -AsPlainText -Force);
							$User = $UsersBox.SelectedItem;$CredDialog.Close()})
	#Cancel Button
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Text = "Cancel"
	$CancelButton.Size = New-Object Drawing.Size(65,25)
	$CancelButton.Location = New-Object System.Drawing.Point(215,130)

	#Main Dailog Window
	$CredDialog = New-Object System.Windows.Forms.Form
	$CredDialog.MaximumSize = New-Object Drawing.Size(400,200)
	$CredDialog.MinimumSize = New-Object Drawing.Size(400,200)
	$CredDialog.Text = "PassPhrase Check Window"
	$CredDialog.AutoSize = $false
	$CredDialog.TopMost = $true
	$CredDialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
	
	#If Failed is true
	if($Failed -eq $true){
		#Add failed message
		$CredDialog.Controls.Add($FailLabel)
	}
	
	#Add components
	$CredDialog.Controls.Add($InfoLabel)
	$CredDialog.Controls.Add($UsersBox)
	$CredDialog.Controls.Add($PassPhraseBox)
	$CredDialog.Controls.Add($PassLabel)
	$CredDialog.Controls.Add($OkButton)
	$CredDialog.Controls.Add($CancelButton)
	$CredDialog.AcceptButton = $OkButton
	$CredDialog.CancelButton = $CancelButton
	
	[void]$CredDialog.ShowDialog()
	
	#get the variables after the dialog is closed
	$Password = (Convertto-secureString -String $PassPhraseBox.Text -AsPlainText -Force);
	$User = $UsersBox.SelectedItem;
	
	return $User,$Password
}

#endregion