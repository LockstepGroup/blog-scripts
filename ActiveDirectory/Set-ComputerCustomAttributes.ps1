###################################################################################################
#
# ScriptName: Set-ComputerCustomAttributes.ps1
# Auther: eshoemaker@lockstepgroup.com
# Last Updated: Q2 2017
# Sets custom Active Directory attributes
# Reference URL:
#
###################################################################################################

###################################################################################################
#                                 REQUIREMENTS
#
# Create custom attributes in AD and attach to the computer class
# Delegate "SELF" permissions to write to the custom attributes created on computer objects
# Set the variables at the beginning of this script to match your custom attributes exactly
# For easy troubleshooting, set the $GenerateLog variable to $True. Be sure to set to $false in 
# production
# 
###################################################################################################



# MODIFY THESE VARIABLES TO MATCH YOUR CUSTOM ATTRIBUTES
$LastLoggedOnUserAttribute="Custom-LastLoggedOnUser"
$LastLoggedOnUserDateAttribute="Custom-LastLoggedOnUserDate"
$HWVendorAttribute="Custom-HardwareVendor"
$HWModelAttribute="Custom-HardwareModel"
$SerialNumberAttribute="SerialNumber"

# TO ENABLE LOGGING, SET THE $GenerateLog VARIABLE TO $true
$GenerateLog=$false
$LogFile="C:\ADCustomAttributes.log"


###################################################################################################
# CREATING LOGGING FUNCTION
# Having the $GenerateLog variable outside the function does not follow coding best practices,
# but it makes it easy to enable/disable logging for this specific script.
###################################################################################################

Function Write-Log {
    param($InputData)
    If ($GenerateLog -eq $true){
        $LogDate=Get-Date
        "$LogDate -- $InputData" | Out-File $LogFile -Append
        }
    }

Write-Log "---------------------STARTING CUSTOM ATTRIBUTE SCRIPT---------------------"


###################################################################################################
#
# GETTING USER AND HARDWARE INFO.
#
###################################################################################################

# GETTING LAST LOGGED ON USER INFO - INTERACTIVE LOGONS ONLY (TYPE 2); RDP LOGONS = (TYPE 10)
$ComputerName=$env:COMPUTERNAME
Write-Log "Computer Name = $ComputerName"
Write-Log "GATHERING LAST LOGGED ON USER INFO"

$30Days=(Get-Date).adddays(-30)

function LogOnSuccess {
        Try {
            $Events = Get-WinEvent -MaxEvents 1 -LogName "Security" -FilterXPath "*[System[(EventID='4624')] and EventData[Data[@Name='LogonType'] and (Data='2' or Data='10' or Data='11')]`
 and EventData[Data[@Name='TargetDomainName']!='Window Manager'] and EventData[Data[@Name='TargetDomainName']!='Font Driver Host']and EventData[Data[@Name='TargetUserName']!='Administrator'] and EventData[Data[@Name='TargetUserName']!='SYSTEM'] and EventData[Data[@Name='TargetUserName']!='SYSTEM'] and EventData[Data[@Name='TargetUserName']!='LOCAL SERVICE'] and EventData[Data[@Name='TargetUserName']!='SCCM_Svc'] and EventData[Data[@Name='TargetUserName']!='NETWORK SERVICE']]" -ErrorAction Stop
            ForEach ($Event in $Events) {
                $eventXML = [xml]$Event.ToXml()
                Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name "TimeCreate" -Value $Event.TimeCreated
                FOREACH ($j in $eventXML.Event.System.ChildNodes) {
                    Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name $j.ToString() -Value $eventXML.Event.System.($j.ToString())
                }
                For ($i=0; $i -lt $eventXML.Event.EventData.Data.Count; $i++) {
                    Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name $eventXML.Event.EventData.Data[$i].name -Value $eventXML.Event.EventData.Data[$i].'#text'
                }
            }
                $global:LoggedOnUser=($Events | select -expand TargetUserName)
                $global:LoggedOnDomain=($Events | select -expand TargetDomainName)
                $global:Date=($Events | select -expand TimeCreate)
                $global:LoggedOnUser=($global:LoggedOnDomain)+'\'+($global:LoggedOnUser)
        }
        Catch { return 'Result: Null'}
    }



LogOnSuccess

Write-Log "Last Logged On User = $LoggedOnUser"


# GETTING COMPUTER HARDWARE INFO
Write-Log "GATHERING HARDWARE INFO"
$HWInfo=Get-WmiObject win32_computerSystem
$HWVendor=$HWInfo.Manufacturer
$HWModel=$HWInfo.Model
$SerialNumber=Get-WmiObject win32_bios | Select -ExpandProperty SerialNumber

Write-Log "Hardware Info = $HWVendor $HWModel"
Write-Log "Serial Number = $SerialNumber"


###################################################################################################
#
# GETTING CURRENT AD COMPUTER OBJECT
#
###################################################################################################

Write-Log "SEARCHING FOR COMPUTER OBJECT $ComputerName"

$Searcher = New-Object adsisearcher
$Searcher.Filter = "(&(name=$ComputerName)(objectcategory=computer))"
$Searcher.PropertiesToLoad.Add("$LastLoggedOnUserAttribute")
$Searcher.PropertiesToLoad.Add("$LastLoggedOnUserDateAttribute")
$Searcher.PropertiesToLoad.Add("$HWVendorAttribute")
$Searcher.PropertiesToLoad.Add("$HWModelAttribute")
$Searcher.PropertiesToLoad.Add("$SerialNumberAttribute")
$Domain=$Searcher.SearchRoot.distinguishedName
$ComputerObj=$Searcher.FindOne()
$ADPath=$ComputerObj.Path

If ($ComputerObj -ne $null){
    Write-Log "$ComputerName FOUND SUCCESSFULLY IN DOMAIN $Domain"
    }
    Else {
        Write-Log "$ComputerName NOT FOUND IN DOMAIN $Domain"
        Write-Log "---------------------ENDING CUSTOM ATTRIBUTE SCRIPT---------------------"
        Exit
        }

# GATHERING CUSTOM ATTRIBUTE VALUES ON THE COMPUTER OBJECT
$LastLoggedOnUserValue = $ComputerObj.Properties.Item($LastLoggedOnUserAttribute)
$LastLoggedOnUserDateValue = $ComputerObj.Properties.Item($LastLoggedOnUserDateAttribute)
$HWVendorValue = $ComputerObj.Properties.Item($HWVendorAttribute)
$HWModelValue = $ComputerObj.Properties.Item($HWModelAttribute)
$SerialNumberValue = $ComputerObj.Properties.Item($SerialNumberAttribute)


###################################################################################################
#
# SETTING AD CUSTOM ATTRIBUTE VALUES WITH USER AND HARDWARE DATA COLLECTED IN PREVIOUS COMMANDS 
# THE ADSI OBJECT IS RECREATED FOR EACH WRITE. THIS PREVENTS AN ERROR ON ONE ATTRIBUTE CAUSING ALL ATTRIBUTE WRITES TO FAIL
# ADDITIONALLY, THE SCRIPT READS THE COMPUTER OBJECT ATTRIBUTE VALUES AND DOESN'T UPDATE THEM IF THEY ARE THE SAME TO PREVENT UNNECESSARY AD REPLICATION
#
###################################################################################################

Write-Log "SETTING CUSTOM ATTRIBUTES ON $ComputerName"

# SPECIFYING FUNCTION FOR SETTING ATTRIBUTES
Function Update-ADAttribute{
    param(
        $ADSIObjectPath,
        $AttributeName,
        $AttributeValue
        )
    Write-Log "ATTEMPTING TO SET $AttributeName ATTRIBUTE TO $AttributeValue"
    $ADObject = [ADSI]”$ADSIObjectPath”
    $ADObject.Put(“$AttributeName”, “$AttributeValue”)
    Try{
        $ADObject.SetInfo()
        Write-Log "$AttributeName SET SUCCESSFULLY"
        } Catch{
            Write-Log "$AttributeName WRITE FAILED"
            Write-Log $Error[0]
            }
    }

# SETTING LOGGED ON USER ATTRIBUTES ONLY IF A USER LOGON FOUND IN THE LAST 30 DAYS. THIS PREVENTS OVER-WRITING THE ATTRIBUTE IF NO USER HAS LOGGED ON IN 30 DAYS
If ($LoggedOnUser -ne $null -and $Date -ne $Null){
    # MODIFYING LOGGED ON USER ATTRIBUTE
    If ($LastLoggedOnUserValue -eq $LoggedOnUser){
        Write-Log "$LastLoggedOnUserAttribute ALREADY SET TO $LoggedOnUser. NOT UPDATING ATTRIBUTE."
        }
        Else {Update-ADAttribute -ADSIObjectPath $ADPath -AttributeName $LastLoggedOnUserAttribute -AttributeValue $LoggedOnUser}

    # MODIFYING LOGGED ON USER DATE ATTRIBUTE
    If ($LastLoggedOnUserDateValue -eq $Date){
        Write-Log "$LastLoggedOnUserDateAttribute ALREADY SET TO $Date. NOT UPDATING ATTRIBUTE."
        }
        Else {Update-ADAttribute -ADSIObjectPath $ADPath -AttributeName $LastLoggedOnUserDateAttribute -AttributeValue $Date}
    }

# MODIFYING HARDWARE VENDOR ATTRIBUTE
If ($HWVendorValue -eq $HWVendor){
    Write-Log "$HWVendorAttribute ALREADY SET TO $HWVendor. NOT UPDATING ATTRIBUTE."
    }
    Else {Update-ADAttribute -ADSIObjectPath $ADPath -AttributeName $HWVendorAttribute -AttributeValue $HWVendor}

# MODIFYING HARDWARE MODEL ATTRIBUTE
If ($HWModelValue -eq $HWModel){
    Write-Log "$HWModelAttribute ALREADY SET TO $HWModel. NOT UPDATING ATTRIBUTE."
    }
    Else {Update-ADAttribute -ADSIObjectPath $ADPath -AttributeName $HWModelAttribute -AttributeValue $HWModel}

# MODIFYING SERIAL NUMBER ATTRIBUTE
If ($SerialNumberValue -eq $SerialNumber){
    Write-Log "$SerialNumberAttribute ALREADY SET TO $SerialNumber. NOT UPDATING ATTRIBUTE."
    }
    Else {Update-ADAttribute -ADSIObjectPath $ADPath -AttributeName $SerialNumberAttribute -AttributeValue $SerialNumber}


# ENDING LOG
Write-Log "---------------------ENDING CUSTOM ATTRIBUTE SCRIPT---------------------"
