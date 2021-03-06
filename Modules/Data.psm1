#Written By: AJ O.
##
#Written On: August 9th 2014
###
#Version: 1.1.0

##########################################################
#Name:DataModule										 #
#                                                        #
#Description: This module is used to provide access to	 #
# logging data processing and data formatting functions	 #
##########################################################


#~Module Control 
#Region
#This function is used to check the current version of the module pack.
#The function returns the version string variable stored in CCSModVerions
function Get-VersionData{
	#The Current version of the Module addin pack
	[String] $ModVersion = "Data Module Version 1.1.0"
	#Return the Current version of the module pack
	Return $ModVersion
}

#This function registers an event engine with a source identifier based
#on the passed in variable.
function Register-Listen{
	Param([Parameter(Mandatory=$true, HelpMessage="The name of the source identifier that you wish to register")][String]$Source)

	#Register an event engine
	Register-EngineEvent -SourceIdentifier $Source -Action {Out-Host -InputObject $Event.MessageData}
}

#This function unregisters an event engine with the source identifier based
#on the passed in variable.
function Unregister-Unlisten{
	Param([Parameter(Mandatory=$true, HelpMessage="The name of the source identifier that you wish to register")][String]$Source)

	#Register an event engine
	Unregister-Event -SourceIdentifier $Source
}
#endregion

#Language Functions
#region

#This function is designed to replace date tags with actual date values. The function
#takes a required string to format as a parameter, as well as an optional hashtable of 
#offset values. Key/Value pairs must follow the following format "d"=#;"m"=#;"y"=#. Negative
#integers CAN be used. The function returns a formated string.
function Format-DateProcess{
	Param([Parameter(Mandatory=$true, HelpMessage="A string to format with date variables.")][String]$InString,
		   [Parameter(Mandatory=$false, HelpMessage="Optional Date offset hashtable. Only key/value pairs that have d,m or y as a keywill be processed. 
		   											The value should be a positive or negative number")][HashTable]$Offset)

	New-Event -SourceIdentifier "Format-DateProcess" -MessageData ("Processing Date InString:{0}" -f $InString)| Out-Null
	#Get current date object
	$Date = Get-Date
	
	#String to retunrn
	$OutString = $InString
	
	#If the offset variable was passed in
	if($Offset){
		#If there is a d key in the offset array
		if($Offset.ContainsKey("y")){$Date = $Date.AddYears([double]$Offset.get_item("y"))}
		#If there is a m key in the offset array
		if($Offset.ContainsKey("m")){$Date = $Date.AddMonths([int]$Offset.get_item("m"))}
		#If there is a m key in the offset array
		if($Offset.ContainsKey("d")){$Date = $Date.AddDays([int]$Offset.get_item("d"))}
	}
	
	#Array of Date formats as they would appear in a string to be processed
	$DateFor = new-object System.Collections.ArrayList(,("DD","dd","MMM","mmm","MM","mm","YYYY","yyyy","YY","yy"))
	
	#Hash table of possible values and their date equivalant
	$DateTab = @{"DD"="Day";"MMM"="Month";"MM"="Month";"YYYY"="Year";"YY"="Year"}

	#Array of date common seperators
	$DateSep = @("-",".","_","/","\")
	
	#For each element in the array
	foreach($Char in $DateFor){
		#Variable to hold the month value
		$DateNum = ""
		#Variable to control while loop
		$done = $false
		#While the passed in string contains the current char and done is false
		While($InString.Contains($Char) -and $done -eq $false){
			#If the char is MMM
			if($Char -eq "MMM"){
				#Get the date variable
				$DateNum = Get-Date -Month (([int]$Date.($DateTab.Get_Item($Char)))) -Format "MMM"
				#Remove the short MM from the hashtable
				$DateTab.Remove("MM")
			}
			#If the char is a 2 digit year
			elseif($Char -eq "YY"){
				#Get the date variable
				$DateNum = [int](((Get-Date).Year).ToString()).SubString(2,2)
				#Remove the long YYYY from the hashtable
				$DateTab.Remove("YYYY")
			}
			else{
				#Get the date variable
				$DateNum = ([int]$Date.($DateTab.Get_Item($Char)))
			}
			#Ensure at least 2 digits are present
			$DateNum = "{0:D2}" -f $DateNum
			
			#Variable representing current string index
			$Sindex = 0
			#while the index variable is less than the length of the string
			while(($Sindex -le $InString.LastIndexOf($Char)) -and $OutString.Contains($Char)){
				#Variable representing whether replacement should take place
				$Replace = $false
				#Get occurance of pattern
				$Sindex = $InString.IndexOf($Char,$Sindex)
				
				#If the previous 2 or following 2 chars are the same as each other
				#The occurence is likely genuine so set replace to true
				if(($InString[($Sindex-1)] -eq $InString[($Sindex-2)]) -or
				($InString[($Sindex+$Char.length)] -eq $InString[($Sindex+$Char.length+1)])){$Replace = $true}
				
				#If the previous or next character is contained in teh Datesep array
				#The occurence is likely genuine
				elseif(($DateSep -contains ($InString[($Sindex-1)])) -or
						($DateSep -contains ($InString[($Sindex+$Char.length)]))){$Replace = $true}
				
				#If the character at the Sindex postition in the InString is not the same as the character in the same
				#position in the Outstring this signifies replacement shouldnt take place
				if($InString[($Sindex)] -ne $OutString[($Sindex)]){$Replace=$false}
				
				#If the replace variable has been set to true
				if($Replace){
					New-Event -SourceIdentifier "Format-DateProcess" -MessageData ("Replacing {0} with {1}" -f $Char,$DateNum)| Out-Null
					#The left side of the string
					$Left = $OutString.Substring(0,$Sindex)
					#The Right side of the string
					$Right = $OutString.Substring(($Sindex + $Char.length),($OutString.Length - ($Sindex + $Char.length)))
					#Assign $Instring the new value
					$OutString = $Left + [String]$DateNum + $Right
				}
				#Increment $Sindex by the length of the char in question
				$Sindex += $Char.length
			}
			#Set done to true
			$done = $true
		}
	}
	#Trim white space
	$OutString = $OutString.Trim()
	New-Event -SourceIdentifier "Format-DateProcess" -MessageData ("Returning {0}" -f $InString)| Out-Null
	#return the string
	return $OutString
}

#This function is designed to determine what type of file it is. The function takes
#a file path as a mandatory variable and returns the extension if found.
function Find-FileType{
	Param([Parameter(Mandatory=$true, HelpMessage="Path of file to determine file type of")][String]$FilePath)
	
	New-Event -SourceIdentifier "Find-FileType" -MessageData ("Begining file detections")| Out-Null
	#Extension
	$Extension = ""
	#Hashtable of headers and fileheaders
	$FileTypes = @{"49492A00"=".tif"; "4D5A"=".exe";"504B0304"=".Zip";"52617221"=".rar";"47494638"=".gif";
					"25504446"=".pdf";"FFD8DD"=".jpg";}
	New-Event -SourceIdentifier "Find-FileType" -MessageData ($FileTypes)| Out-Null
	#If the file exists
	if(test-path -Path $FilePath){
		#Get the file header
		$FileHeader = Get-Content -Path $FilePath -Encoding Byte -TotalCount 10
		#Variable to hold hex header
		$HexHeader = ""
		#Foreach element in the $Fileheader array
		Foreach($byte in $FileHeader){
			#Convert o hex and add to string variabl
			$HexHeader += "{0:X2}" -f $byte
		}
		#Foreach element in the keys array
		Foreach($Id in $FileTypes.Keys){
			#If the Header starts with the current id
			if($HexHeader.StartsWith($Id)){
				#Get the extension
				$Extension = $FileTypes.get_item($Id)
				New-Event -SourceIdentifier "Find-FileType" -MessageData ("SUCCESS:Extension found: File header {0} matches type {1}" -f $Id,$Extension)| Out-Null
				break
			}
		}
		#Return the extension
		return $Extension
	}
	else{
		New-Event -SourceIdentifier "ChangeMe" -MessageData ("FAIL:{0} was not a vaild file path." -f $FilePath) | Out-Null
	}
}

#This function is used to format a string to ensure it is in an
#acceptable format and removed of special characters. The function takes a
#string to format and produces a formatted string.
function Format-String{
	Param([Parameter(Mandatory=$true, valueFromPipeline=$true, HelpMessage="A string or array of strings to format.", Position=0)][String]$InString,
		  [Parameter(Mandatory=$false, HelpMessage="This specifies which array(s) to use when formatting. If none is
		  			is specified, all arrays are used", Position=1)][ValidateSet("Special","Space")][String]$ArrayType)
	
	New-Event -SourceIdentifier "Format-String" -MessageData ("Formatting {0} using the {1} array" -f $InString,$ArrayType)| Out-Null
	#String to return
	$ReturnString = ""
	#Array of characters to use in formatting
	[Array] $SpecChar = @()
	
	#Array of special characters to remove more can be added as needed
	$SpecialChar = @(" ", "!", ".", "#", "$", "%", "^", ",", "*", "(", ")")
	$SpaceChar = @("`n", "`r", "`n`r", "`t")
	
	#If array type is special assign the specialchar array
	if($ArrayType -eq "Special"){$SpecChar = $SpecialChar}
	#Else if array type is space assign the spacechar array
	elseif($ArrayType -eq "Space"){$SpecChar = $SpaceChar}
	else{
		#Assign all arrays
		$SpecChar = $SpecialChar
		$SpecChar += $SpaceChar
	}
	
	#For each element in the array
	foreach($Char in $SpecChar){
			#If the passed in string contains the current value
			While($InString.Contains($Char)){
				#Remove the illegal character
				$InString = $InString.Replace($Char, "")
			}
			#Trim white space
			$InString = $InString.Trim()
	}
	#Add the return string to the return array
	$ReturnString = $InString

	New-Event -SourceIdentifier "Format-String" -MessageData ("Returning {0}" -f $ReturnString)| Out-Null
	#Return the string 
	return $ReturnString
}

#This function splits a string of text by a deliminting character and removes illegals.
#The function takes a string and delimiting character or pattern as
#input and returns an array of seperated values
#If illegals removal is not required, consider not using this function
function Format-Seperate{
	Param([Parameter(Mandatory=$true,HelpMessage="A string of values to seperate")][String]$Data,
			[Parameter(Mandatory=$true,HelpMessage="Character or pattern to split on")][String]$Delim)
			
		New-Event -SourceIdentifier "Format-Seperate" -MessageData ("Splitting String " + $Data + " on " + $Delim) | Out-Null
		#Split on character
		$SplitArray = $Data.Split($Delim)
		#Final format array
		[Array]$FinalArray = @()
		#For each element in the array
		foreach($Var in $SplitArray){
			#If the variable is not null
			if($Var.length -gt 0){
				#Add value to final array
				$FinalArray += $Var
			}
			else{
				New-Event -SourceIdentifier "Format-Seperate" -MessageData ("A blank value was not processed")| Out-Null
			}
		}
		#return the final array
		return $FinalArray
}

#This function is designed to check if a folder path ends with a slash - the type of slash
#depends on local or remote path. The function takes a string to check and a character representing
#which slash to use. The function returns a formatted string.
function Format-ValidateFolder{
	Param([Parameter(Mandatory=$true, HelpMessage="A string to check folder syntax")][String]$Folder,
			[Parameter(Mandatory=$true, HelpMessage="Slash direction used in path: \  or /")][ValidateSet("/","\")][char]$Slash)
	
	New-Event -SourceIdentifier "Format-ValidateFolder" -MessageData ("Validating folder {0}" -f $Folder)| Out-Null
	#return string
	$ReturnString = $Folder
	switch($Slash){
		"\"{
		New-Event -SourceIdentifier "Format-ValidateFolder" -MessageData ("Processing \")| Out-Null
		#If the path doesn't end with a \
		if(-not($Folder.endswith("\"))){$ReturnString = $Folder + "\"}
		}
		"/"{
		New-Event -SourceIdentifier "Format-ValidateFolder" -MessageData ("Processing /")| Out-Null
		#If the path doesn't end with a \
		if(-not($Folder.endswith("/"))){$ReturnString = $Folder + "/"}
		}
	}
	return $ReturnString
}

#endregion

#Log Functions
#region

#Used to write output to the host. Takes a message to be written
#as a required parameter and outputs it to the console.
function Write-Console{
	Param([Parameter(Mandatory=$true,valueFromPipeline=$true,HelpMessage="The message to be written.")][String]$Message)

	#Cast input to string
	$Message = [String]$Message
	#Output message to console
	Out-Host -InputObject $Message
}

#This function is used to write either a start of log stamp or end of log
#stamp for the current run. The function takes two mandatory parameters: A string
#as the path to a log file and a boolean indicating whether to write the start stamp
#or the end stamp
function Write-LogStamp{
	Param([Parameter(Mandatory=$true, HelpMessage="Full log file path.")][String]$LogPath,
		[Parameter(Mandatory=$true, HelpMessage="If this is true then the start stamp is written, if false then the end stamp is written.")][boolean]$Start)
	
	switch ($Start){
		$false{
			WriteLog -LogPath $LogPath -Message ("`n-----ENDLOG-DATE:{0} USER:{1} MACHINE:{2} -----`n" -f (Get-Date),$ENV:USERNAME,$Env:COMPUTERNAME)
		}
		$true{
			WriteLog -LogPath $LogPath -Message ("`n-----STARTLOG-DATE:{0} USER:{1} MACHINE:{2} -----`n" -f (Get-Date),$ENV:USERNAME,$Env:COMPUTERNAME)
		}
	}
}

#This function is designed to scan the passed in log file for successfully
#completion and email the results to the provided address
function Write-SendLog{
	Param([Parameter(Mandatory=$true, HelpMessage="This is the full path to the scripts log file")][String]$LogPath,
		  [Parameter(Mandatory=$true, HelpMessage="This is the full path to the scripts error log file")][String]$ErrorLogPath,
		  [Parameter(Mandatory=$true, HelpMessage="The address of the receipient")][String]$To,
		  [Parameter(Mandatory=$true, HelpMessage="The address of the sender")][String]$From,
		  [Parameter(Mandatory=$true, HelpMessage="An active, accessible, SMTP server address")][String]$Smtp,
		  [Parameter(Mandatory=$false, HelpMessage="An array of file paths of attachments to add")][Array]$Attach,
		  [Parameter(Mandatory=$false, HelpMessage="An optional subject to use.")][String]$InSubject,
		  [Parameter(Mandatory=$false, HelpMessage="An optional date used as the start point for error log checking")][System.DateTime]$InDate)
	
	#If the log file exists
	if(Test-Path -Path $LogPath){
		#date of start of script
		$DateBeg = Get-Date

		#if there is a passed in Date
		if($InDate -ne $null){$DateBeg = $InDate}
		
		#Attachments
		$Attachments = @()
		#name of script
		$ScriptName = $LogPath.SubString(($LogPath.LastIndexOf("\")+1),($LogPath.LastIndexOf(".")-($LogPath.LastIndexOf("\")+1)))
		#Array of links
		$links = @("\\","X:\","C:\")
		#Array of text/color pairs * must be in format "text,hex color" for successes
		$textIdS = @("success","found","succeed","Everything is Ok")
		#Array of text/color pairs * must be in format "text,hex color" for failures
		$textIdF = @("fail","not found")
		#integers representing final success fail counts
		$finSucc = 0; $finFail = 0;
		#if attachments are present
		if($Attach.Count -gt 0){
			#for each path
			foreach($a in $Attach){
				#if the path exists
				if(Test-Path -Path ([String]$a)){$Attachments+=$a}
			}
		}
		#Variable to hold latest log entry
		[String]$LatestLog
		new-event -SourceIdentifier "SendLog" -MessageData ("Reading in Log file {0} now" -f $LogPath) | out-null
		#Read in the log file
		$LogFile = [System.IO.File]::ReadAllLines($LogPath)
		new-event -SourceIdentifier "SendLog" -MessageData ("Reading in last modified error log time now from {0}" -f $ErrorLogPath) | out-null
		#Last modified date of the error file
		if(Test-Path -Path $ErrorLogPath){$ErrorTime = [System.IO.File]::GetLastWriteTime($ErrorLogPath)}
		new-event -SourceIdentifier "SendLog" -MessageData ("Composing name of script") | out-null
		#Cast Log file to array
		[Array] $LogFile = $LogFile
		#Variable to hold position in array
		$pos = 0
		new-event -SourceIdentifier "SendLog" -MessageData ("Finding final log entry...") | out-null
		#while loop to get the latest log entry
		while($pos -lt $LogFile.Count){
			#Get the current line
			[String] $line = $LogFile[$pos]
			#If the line contains the logfile start indicator
			if($line.contains("STARTLOG-DATE")){
				#Clear the $LatestLog variable to ensure only the most recent entry is left
				$LatestLog = @("<body><html><table>")
				#while the line does not contain the endlog indicator
				while((-not($line.contains("ENDLOG-DATE"))) -and ($pos -lt $LogFile.Count)){
					#If the line contains the logfile start indicator
					if($line.contains("STARTLOG-DATE")){$LatestLog = @("<body><html><table>")}					
					#add the line to the $LatestLog variable
					$LatestLog += $line
					#increment pos
					$pos++
					#Get the next current line
					[String] $line = $LogFile[$pos]
				}
				#add the line to the $LatestLog variable
				$LatestLog += ($line + "</br>")
			}
			#increment pos
			$pos++
		}
		new-event -SourceIdentifier "SendLog" -MessageData ("Begining log analysis now...") | out-null
		#set pos to 0
		$pos = 0
		#pos is less than the logs length
		while($pos -lt $LatestLog.Count){
			#pos variable for string to char array conversion
			$posChar = 0
			#CUrrent line as array of characters
			$loglineC = @()
			#variable to hold table cell start tag
			$TableCell = "<td style=`"vertical-align:top`">"
			#add each character to the char array
			while($posChar -lt $LatestLog[$pos].length){
				#Current character
				$CurrChar = $LatestLog[$pos].SubString($posChar,1).TrimStart()
				#if the current character length is 0 signifying a space# add a space
				if($CurrChar.length -eq 0){$loglineC += " "}
				#add the character
				else{$loglineC += $CurrChar}
				#increment by 1
				$posChar++
			}
			#links array postion
			$linkPos = New-Object System.Collections.ArrayList(,(""))
			new-event -SourceIdentifier "SendLog" -MessageData ("Finding all relative links on current line...") | Out-Null
			#foreach of the links find all occurances
			foreach($l in $links){
				#Char array
				$lchar = $l.ToCharArray()
				#variable to control while loop
				$posin = 0
				while($posin -lt $loglineC.length){
					#variable to control char array postion
					$lpos = 0
					#If the character equals the first charcter
					if($loglineC[$posin] -eq $lchar[$lpos]){
						#number of matches
						$nummat = 0
						#start value of posin
						$posinstart = $posin
						#while the two equal each other
						while($loglineC[$posin] -eq $lchar[$lpos]){
							#increment nummat by 1
							$nummat++
							#increment $lpos by one
							$lpos++
							#increment $posin by one
							$posin++
						}
						if($nummat -eq $lchar.count){
							#add the index to the array
							$linkPos.add($posinstart) | Out-null
						}
					}
					#increment $posin by one
					$posin++
				}
			}
			new-event -SourceIdentifier "SendLog" -MessageData ("Finding all relative key words on current line...") | out-null
			#boolean Variables representing success and failures 
			$success = $false; $fail = $false;
			#integer to control while loops
			$posLoop = 0;
			#foreach of the success keywords indicate if one is present on the line
			while(($success -eq $false) -and ($posLoop -lt $textIdS.Count)){
				#get the word out
				$phrase = $textIdS[$posLoop]
				#Char array
				$lchar = $phrase.ToCharArray()
				#variable to control while loop
				$posin = 0
				while($posin -lt $loglineC.length){
					#variable to control char array postion
					$lpos = 0
					#If the character equals the first charcter
					if(($loglineC[$posin] -eq $lchar[$lpos]) -or ($loglineC[$posin].ToLower() -eq $lchar[$lpos]) -or ($loglineC[$posin].ToUpper() -eq $lchar[$lpos])){
						#number of matches
						$nummat = 0
						#start value of posin
						$posinstart = $posin
						#while the two equal each other
						while($posin -lt $loglineC.length -and (($loglineC[$posin] -eq $lchar[$lpos]) -or ($loglineC[$posin].ToLower() -eq $lchar[$lpos]) -or ($loglineC[$posin].ToUpper() -eq $lchar[$lpos]))){
							#increment nummat by 1
							$nummat++
							#increment $lpos by one
							$lpos++
							#increment $posin by one
							$posin++
						}
						if($nummat -eq $lchar.count){
							#Set success to true
							$success = $true
							break
						}
					}
					#increment $posin by one
					$posin++
				}
				#Increment the loop variable
				$posLoop++
			}
			#integer to control while loops
			$posLoop = 0;
			#foreach of the failure keywords indicate if one is present on the line
			while(($fail -eq $false) -and ($posLoop -lt $textIdF.Count)){
				#get the word out
				$phrase = $textIdF[$posLoop]
				#Char array
				$lchar = $phrase.ToCharArray()
				#variable to control while loop
				$posin = 0
				while($posin -lt $loglineC.length){
					#variable to control char array postion
					$lpos = 0
					#If the character equals the first charcter
					if(($loglineC[$posin] -eq $lchar[$lpos]) -or ($loglineC[$posin].ToLower() -eq $lchar[$lpos]) -or ($loglineC[$posin].ToUpper() -eq $lchar[$lpos])){
						#number of matches
						$nummat = 0
						#start value of posin
						$posinstart = $posin
						#while the two equal each other
						while($posin -lt $loglineC.length -and (($loglineC[$posin] -eq $lchar[$lpos]) -or ($loglineC[$posin].ToLower() -eq $lchar[$lpos]) -or ($loglineC[$posin].ToUpper() -eq $lchar[$lpos]))){
							#increment nummat by 1
							$nummat++
							#increment $lpos by one
							$lpos++
							#increment $posin by one
							$posin++
						}
						if($nummat -eq $lchar.count){
							#Set success to true
							$fail = $true;
							break
						}
					}
					#increment $posin by one
					$posin++
				}
				#Increment the loop variable
				$posLoop++
			}
			#If the success variable is true and fail is false
			if(($success -eq $true) -and ($fail -eq $false)){
				#increment success variable
				$finSucc++
				#set the tablecell color
				$TableCell = ("<td style=`"vertical-align:top`" bgcolor=`"{0}`">" -f "52FF52")
			}
			elseif(($fail -eq $true)){
				#increment fail variable
				$finFail++
				#set the tablecell color
				$TableCell = ("<td style=`"vertical-align:top`" bgcolor=`"{0}`">" -f "FCBAB8")
			}
			else{
				#set the tablecell
				$TableCell = ("<td style=`"vertical-align:top`">")
			}
			
			#string to hold constructed line
			$conline = ""
			#construct a string from the array
			foreach($ch in $loglineC){
				#add the character to the string
				$conline += $ch
			}
			
			#Convert logline to a string
			$logline = [String]$conline
			#variable to control linkpos while loop
			$Linkpospos = 0
			#variable to hold links to replace
			$linkText = New-Object System.Collections.ArrayList(,(""))
			#Sort the arraylist
			$linkPos.Sort()
			#while $Linkpospos is less than the size of the $linkpos array
			while(-not($linkPos.count -eq 0) -and ($Linkpospos -lt $linkPos.count)){
				#if the $linkPos array contains only 1 start value
				if(($linkPos.count -eq 1) -or ($Linkpospos -eq ($linkPos.count-1))){
					#get the last index of \
					$Lastof = $logline.lastindexof("\")
				}
				else{
					#variable to control while loop
					$Lastofpos = 0
					#Last index of \
					$Lastof = 0
					#Get the last occurance of "\" before the next link
					while($Lastofpos -lt $linkPos[$Linkpospos+1]){
						#get the index of the next slash
						$Lastofpos = $logline.indexof("\",$Lastofpos+1)
						#if the index is not greater than the next link start point
						if($Lastofpos -lt $linkPos[$Linkpospos+1]){
							#assign the value to $Lastof
							$Lastof = $Lastofpos
						}
					}
				}
				#get the substring between the two positions
				$linkTextLine = $logline.SubString($linkPos.item($Linkpospos),($Lastof-$linkPos.item($Linkpospos)))
				#if linktext array does not already contain the string
				if(-not($linkText.contains($linkTextLine))){
					#add to the array
					$linkText.add($linkTextLine) | Out-Null
				}
				#increment by 1
				$Linkpospos++
			}
			#sort the array list
			$linkText.Sort()
			#foreach item in the linktext array
			foreach($item in $linkText){
				#Replace the text with a hyperlink
				$logline = $logline.replace($item,("<a href=`"{0}`">{0}</a>" -f $item))
			}
			#if the line does not start with an html tag
			if(-not($LatestLog[$pos].StartsWith("<"))){
				#Replace the string with a table row html string
				$LatestLog[$pos] = "<tr><td style=`"width:175px;vertical-align:top`">" + $logline.substring(0,($logline.indexof("M")+1)) + "</td>" + $TableCell + $logline.substring($logline.indexof("M")+1,($logline.length-($logline.indexof("M")+1))) + "</td></tr>"
			}
			#increment $pos by 1
			$pos++
		}
		#Add html closing tags to the LatestLog variable
		$LatestLog += "</html></body></table>"
		new-event -SourceIdentifier "SendLog" -MessageData ("Log analysis is now complete") | out-null
		#If the error log has not been written to today
		if(($ErrorTime -eq $null) -or ($ErrorTime -lt $DateBeg)){			
			#If there is a passed in subject
			if($InSubject.Length -gt 0){
				#Set subject to include the passed in subject
				$Subject = ($InSubject + ("({0}):Successes ({1}):Failures" -f $finSucc,$finFail))
			}
			else{
				new-event -SourceIdentifier "SendLog" -MessageData ("SUCCESS:Sending success email") | out-null
				#Subject for email
				$Subject = "{0} has completed successfully ({1}):Successes ({2}):Failures" -f $ScriptName,$finSucc,$finFail
			}
		}
		else{
			new-event -SourceIdentifier "SendLog" -MessageData ("FAIL:Sending error email now") | out-null
			#Subject for email
			$Subject = "{0} may have encountered errors. Please check the log files to confirm. ({1}):Successes ({2}):Failures" -f $ScriptName,$finSucc,$finFail
			#Add the error log to that attachments array
			$Attachments += $ErrorLogPath
		}
		#Convert the message to a string
		[String] $Body = $LatestLog		
		#if the attachs array is 0
		if($Attachments.Count -gt 0){
			#Send email with attachmnents
			Send-MailMessage -To $To -From $From -SmtpServer $Smtp -Subject $Subject -Body $Body -BodyAsHtml -Attachments $Attachments
		}
		else{
			#send mail without attachments
			Send-MailMessage -To $To -From $From -SmtpServer $Smtp -Subject $Subject -Body $Body -BodyAsHtml
		}
	}
	else{
		new-event -SourceIdentifier "Error" -MessageData ("FAIL:Unable to locate log file {0}" -f $LogPath) | out-null
	}
	new-event -SourceIdentifier "SendLog" -MessageData ("SendLog function complete") | out-null
}

#Used to write to both the console and the log. The function takes
#an optional log path and requried message. It then calls the 
#appropriate functions.
function Write-CL{
	Param([Parameter(Mandatory=$false, HelpMessage="Full log file path.")][String]$LogPath,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=1, HelpMessage="The message to be written.")][String]$Message)
		
		#Write to the log file
		WriteLog -logPath $LogPath -message $Message
		#Write to console
		Console -Message $Message
}

#This function writes to a log file. The log file takes a message
#as a required parameter and a log path as an optional parameter.
#If a log path is not supplied then the Global log path variable
#is used.
function Write-Log{
	Param([Parameter(Mandatory=$true, HelpMessage="Full log file path.")][String]$LogPath,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0, HelpMessage="The message to be written.")][String]$Message)
	
	process
	{
	#Array to hold messages to write
	$MessageArray = @()
	
	#If the message contains a new line indicator
	if($Message.Contains("`n")){
		#Split on the new line character
		$TempMess = $Message.Split("`n")
		#foreach message
		foreach($Mess in $TempMess){
			#format message with date
			$MessageArray += (([String] (Get-Date -Format "g")) + "`t" + $Mess)
		}
	}
	else{
		#format message with date
		$MessageArray += (([String] (Get-Date -Format "g")) + "`t" + $Message)
	}
	
	#Foreach message in the message array
	Foreach($OutMess in $MessageArray){
		#Write to the file
		Out-File -FilePath $local:LogPath -Append -InputObject $OutMess
	}
	}
}

#endregion

#Query Functions
#region

#This function is used to check if the host value passed to
#it exists as a host on the local network. It takes a host name
#as input and returns true or false
function Test-HostStatus{
	Param([Parameter(Mandatory=$true, HelpMessage="The computer to query.")][String]$CHost)
	
	#create commmand
	$Com = "ping -n 2 " + $CHost
	#Ping the host
	Invoke-Expression ($Com) | Out-Null
	#if the command succeeded
	if($LASTEXITCODE -eq 0){
		#return true
		return $true
	}
	else{
		#return false
		return $false
	}
}

#This function is used to check if a directory exists. The function
#takes a mandatory parameter representing the directory path. THe function
#tests if the folder exists and if not creates it.
function Test-Directory{
	Param([Parameter(Mandatory=$true,HelpMessage="The Folder to check if it exists")][String]$InPath)
	
	New-Event -SourceIdentifier "Test-Directory" -MessageData ("Checking for existance of {0}" -f $InPath) | Out-Null
	#If the folder does not exists
	If(-not(Test-Path -Path $InPath)){
		New-Event -SourceIdentifier "Test-Directory" -MessageData ("{0} not found; creating folder now..." -f $InPath) | Out-Null
		#Create the new folder
		New-Item -Path $InPath -ItemType Directory | Out-Null
		New-Event -SourceIdentifier "Test-Directory" -MessageData ("Directory created at{0}." -f $InPath) | Out-Null
	}
	else{
		New-Event -SourceIdentifier "DirectoryCheck" -MessageData ("{0} found" -f $InPath) | Out-Null
	}
	#Return the string
	Return $InPath
}

#This function is used to query a computer for disk information
#The function takes a computer name as a variable and 
#returns an array of WMIObjects
function Get-DiskInfo{
	Param([Parameter(Mandatory=$true, HelpMessage="The computer to query.")][String]$Computer)
	New-Event -SourceIdentifier "Get-DiskInfo" -MessageData  ("Begining Query of " + $Computer) | Out-Null
	#Get information about the supplied computers disks
	$Diskinfo = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $Computer
	New-Event -SourceIdentifier "Get-DiskInfo" -MessageData  ("Query of " + $Computer + " is now complete.") | Out-Null
	#return said information
	return $Diskinfo

}

#endregion

#UI Funtions
#region

#This function is used to modify the powershell console title and color
function Edit-Console{
	Param([Parameter(Mandatory=$true, HelpMessage="The title displayed in the tool bar")][String]$title)
	
	#Current machine
	$hostRawUi = (Get-Host).UI.RawUI
	#Change the window properties
	$hostRawUi.WindowTitle = $title
	#Change the size
	$hostRawUi.WindowSize.Width = 800
	$hostRawUi.WindowSize.Height = 600
}

#endregion

#Xml Functions
#Region

#This function is used to check if a node exists. It takes  a config file, the name
#of the rootnode and the node in which to check if it exists.
function Test-Node{
	Param([Parameter(Mandatory=$true, HelpMessage="Case Sensitive name of the Root Node.")][String]$RootNode,
		[Parameter(Mandatory=$true, HelpMessage="Case Sensitive name of the node with the stored value.")][String]$Node,
		[Parameter(Mandatory=$true, HelpMessage="The full path to the XML file")][String]$XMLFile)
	
		#If the config file is present
		if((Test-Path $XMLFile)){
			new-event -SourceIdentifier "Test-Node" -MessageData ("Configuration file {0} path check successfull." -f $XMLFile) | out-null
			new-event -SourceIdentifier "Test-Node" -MessageData ("Formatting nodes {0},{1}" -f $Node,$RootNode) | out-null
			#format nodes
			$Node = FormatString -InString $Node
			$RootNode = FormatString -InString $RootNode
			new-event -SourceIdentifier "Test-Node" -MessageData "Getting XML file" | out-null
			#Temporary File
			$TempConfig = [xml] (get-content -Path $XMLFile)
			#If the rootnode passed in is not the document root
			if($RootNode -eq (($TempConfig.DocumentElement).Name)){
				#Set Root element with $RootNode
				$InstallRoot = $TempConfig.$RootNode
			}
			else{
				#Set Root element with $RootNode using DocumentElement
				$InstallRoot = $TempConfig.DocumentElement.$RootNode
			}
			
			new-event -SourceIdentifier "Test-Node" -MessageData ("Gettting Node {0}" -f $Node) | out-null
			#Resulting node
			$ResNode = $InstallRoot.SelectSingleNode($Node)
			#If the node exists
			if(-not($resNode -eq $null)){
				new-event -SourceIdentifier "Test-Node" -MessageData ("Result Node {0} present." -f $resNode) | out-null
				return $true
			}
			else{
				new-event -SourceIdentifier "Test-Node" -MessageData ("FAIL:Result Node  {0} not present." -f $resNode) | out-null
				return $false
			}
		}
		else{
			new-event -SourceIdentifier "Test-Node" -MessageData ("FAIL:XML file {0} not present." -f $XMLFile) | out-null
		}
}

#This function is used to get the value associated with a node.
#It takes the root node, the node which has the value needed
#and the full path to the configuration file as arguments.
#It 
function Get-NodeValue{
	Param([Parameter(Mandatory=$true, HelpMessage="Case Sensitive name of the Root Node.")][String]$RootNode,
		[Parameter(Mandatory=$true, HelpMessage="Case Sensitive name of the node with the stored value.")][String]$Node,
		[Parameter(Mandatory=$true, HelpMessage="The full path to the XML file")][String]$ConfigFile,
		[Parameter(Mandatory=$false, HelpMessage="Boolean value indicating whether to return the XML node rather than the value.")][Boolean]$NodeReturn=$false)

	try{
		#If the config file is present
		if((Test-Path $ConfigFile)){
			new-event -SourceIdentifier "Get-NodeValue" -MessageData ("Configuration file {0} path check successfull." -f $ConfigFile) | out-null
			new-event -SourceIdentifier "Get-NodeValue" -MessageData ("Formatting nodes {0},{1}" -f $Node,$RootNode) | out-null
			#format nodes
			$Node = FormatString -InString $Node
			$RootNode = FormatString -InString $RootNode
			new-event -SourceIdentifier "Get-NodeValue" -MessageData "Getting XML file" | out-null
			#Temporary File
			$TempConfig = [xml] (get-content -Path $ConfigFile)
			#If the rootnode passed in is not the document root
			if($RootNode -eq (($TempConfig.DocumentElement).Name)){
				#Set Root element with $RootNode
				$InstallRoot = $TempConfig.$RootNode
			}
			else{
				#Set Root element with $RootNode using DocumentElement
				$InstallRoot = $TempConfig.DocumentElement.$RootNode
			}
			
			new-event -SourceIdentifier "Get-NodeValue" -MessageData ("Gettting Node {0}" -f $Node) | out-null
			#Resulting node
			$ResNode = $InstallRoot.SelectSingleNode($Node)
			#If the node exists
			if(-not($ResNode -eq $null)){
				 new-event -SourceIdentifier "Get-NodeValue" -MessageData ("Node fetching process complete. Returning {0}" -f $ResNode.get_InnerText())  | out-null
				 switch($NodeReturn){
					 $false{
						 #return value of the element
						 return [String] $ResNode.get_InnerText()
					 }
					 $true{
					 	 #return the element
						 return $ResNode
					 }
				 }
			}
			else{
				#Output error to necessary sources
				new-event -SourceIdentifier "Get-NodeValue" -MessageData ("FAIL:No node was found")  | out-null
			}
		}
		else{
			#Output error to necessary sources
			new-event -SourceIdentifier "Get-NodeValue" -MessageData ("FAIL:Configuration file path is invalid.")  | out-null
		}
	}
	catch{
		if($Error){new-event -SourceIdentifier "Error" -MessageData $Error | out-null }
		#Output error to necessary sources
		new-event -SourceIdentifier "Error" -MessageData $_.Exception.Message  | out-null
		break
	}
}

#$rootnode: The node in which the search for $node begins
#$node: The node in which to modify or create
#$value: The value to assign to the newly created node
function Edit-Node{
	Param([Parameter(Mandatory=$true, HelpMessage="Case Sensitive name of the Root Node.")][String]$RootNode,
		[Parameter(Mandatory=$true, HelpMessage="Case Sensitive name of the node with the stored value.")][String]$Node,
		[Parameter(Mandatory=$true, HelpMessage="The full path to the XML file")][String]$XMLFile,
		[Parameter(Mandatory=$false, HelpMessage="Value to update with")][String]$Value)

	try{
		#If the config file is present
		if(Test-Path -Path $XMLFile){
			#Temporary File
			$tempConfig = [xml] (Get-Content -Path $XMLFile)
			#Set Root element with $rootNode
			$installRoot = $tempConfig.$RootNode
			#if the node is found
			if((-not($installRoot -eq $null)) -and (-not($installRoot -eq ""))){
				#Resulting node
				$resNode = $installRoot.SelectSingleNode($Node)
				#If the node exists
				if($resNode -eq $null){
					#Create a new xml element
					$xmlEle = $tempConfig.CreateElement($Node)
					#Add the new Child node
					$installRoot.AppendChild($xmlEle) | Out-Null
					#Resulting node
					$resNode = $installRoot.SelectSingleNode($Node)
				}
				if(-not($Value -eq $null)){
					#Set the specified element to the provided value
					$resNode.Set_InnerText($Value)
				}
				#Create XML Writter Settings
				$xmlSett = new-object System.Xml.XmlWriterSettings
				#Set the settings
				$xmlSett.Indent = $true
				$xmlSett.NewLineHandling = "Entitize"
				#Create xml writter
				$xmlWritter = [System.Xml.XmlWriter]::Create($XMLFile, $xmlSett)
				#Save the config file
				$tempConfig.WriteTo($xmlWritter)
				#close the xml writter
				$xmlWritter.Close()
			}
			else{
				new-event -SourceIdentifier "Edit-Node" -MessageData ("FAIL:No root node was found matching that name.") | out-null 
			}
		}
		else{
			new-event -SourceIdentifier "Edit-Node" -MessageData ("FAIL:XML file {0} not present." -f $XMLFile) | out-null
		}
	}
	catch{
		if($Error){new-event -SourceIdentifier "Error" -MessageData $Error | out-null }
		#Output error to necessary sources
		new-event -SourceIdentifier "Error" -MessageData $_.Exception.Message  | out-null
		break
	}
}

#endregion