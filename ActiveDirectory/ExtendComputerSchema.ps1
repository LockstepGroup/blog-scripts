<#
Extend User Schema
Script: ExtendComputerSchema.ps1
Reference URL: https://www.linkedin.com/pulse/using-powershell-extend-user-schema-active-directory-james-sargent/
 
Author: James Sargent
Created: 2019/03/19
 
Summary
This script creates AD Attributes for computers; after running the script successfully, you should see additional attributes assigned to the computer.  
Always test your schema changes in a test environment before making any changes.
 
Requirements
PowerShell 4.0 or higher
AD PowerShell Modules (RSAT)
 
 
CSV Not Used -CSV File configuration
CSV Not Used -Name,oMSyntax,AttributeSyntax,isSingleValued,Description,Indexed

Custom-LastLoggedOnUser – Last logged on user
Custom-LastLoggedOnUserDate – Last time the user logged on
Custom-HardwareVendor – Hardware Manufacturer
Custom-HardwareModel – Hardware Model
Custom-SerialNumber – for populating the serial number of each computer
Custom-SNID - Acer specific SNID if available

Name: Should not have any characters other than letters or numbers
oMSyntax and AttributeSyntax: These settings can be found here https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/7cda533e-d7a4-4aec-a517-91d02ff4a1aa
isSingleValued: True or False
Description:  Keep it short, I avoid commas in mine
Indexed: Yes or No
#>
 
# Set the path and file name to your import file
#$arrAttributes = Import-CSV "c:\Scriptes\NewAttributes.csv"
# hard coded Attributeds
# Name,oMSyntax,AttributeSyntax,isSingleValued,Description,Indexed
$arrAttributes = @()
$arrAttributes = @(
("Custom-LastLoggedOnUser","64","2.5.5.12","TRUE","Last logged on user","YES"),
("Custom-LastLoggedOnUserDate","64","2.5.5.12","TRUE","Last time the user logged on","YES"),
("Custom-HardwareVendor","64","2.5.5.12","TRUE","Hardware Manufacturer","YES"),
("Custom-HardwareModel","64","2.5.5.12","TRUE","Hardware Model","YES"),
("Custom-SerialNumber","64","2.5.5.12","TRUE","For populating the serial number of each computer","YES"),
("Custom-SNID","64,2.5.5.12","TRUE","Acer specific SNID if available","YES")
)


# DO NOT EDIT BELOW THIS LINE
# ----------------------------------------------------------------------
 
function funGenOID
{
<#         Orignal code for generating an OID
https://gallery.technet.microsoft.com/scriptcenter/Generate-an-Object-4c9be66a
 
Generates an object identifier (OID) using a GUID and the OID prefix 1.2.840.113556.1.8000.2554. This is a PowerShell equivalent of VBScript published here: http://gallery.technet.microsoft.com/scriptcenter/56b78004-40d0-41cf-b95e-6e795b2e8a06/
#>
 
$Prefix="1.2.840.113556.1.8000.2554" 
$GUID=[System.Guid]::NewGuid().ToString() 
$Parts=@() 
$Parts+=[UInt64]::Parse($guid.SubString(0,4),"AllowHexSpecifier") 
$Parts+=[UInt64]::Parse($guid.SubString(4,4),"AllowHexSpecifier") 
$Parts+=[UInt64]::Parse($guid.SubString(9,4),"AllowHexSpecifier") 
$Parts+=[UInt64]::Parse($guid.SubString(14,4),"AllowHexSpecifier") 
$Parts+=[UInt64]::Parse($guid.SubString(19,4),"AllowHexSpecifier") 
$Parts+=[UInt64]::Parse($guid.SubString(24,6),"AllowHexSpecifier") 
$Parts+=[UInt64]::Parse($guid.SubString(30,6),"AllowHexSpecifier") 
$OID=[String]::Format("{0}.{1}.{2}.{3}.{4}.{5}.{6}.{7}",$prefix,$Parts[0],$Parts[1],$Parts[2],$Parts[3],$Parts[4],$Parts[5],$Parts[6]) 
Return $oid 
}
  
# Set Schema Path
$schemaPath = (Get-ADRootDSE).schemaNamingContext
 
# Get Computer Schema Object
$ComputerSchema = get-adobject -SearchBase $schemapath -Filter 'name -eq "computer"'
 
ForEach ($tmpAttrib in $arrAttributes)
{
# Build OtherAttributes
$Attribute = @{
  lDAPDisplayName = $tmpAttrib.Name;
  attributeId = funGenOID
  oMSyntax = $tmpAttrib.oMSyntax;
  attributeSyntax =  $tmpAttrib.AttributeSyntax;
  isSingleValued = if ($tmpAttrib.isSingleValued -like "*true*") {$True} else {$false};
  adminDescription = $tmpAttrib.Description;
  searchflags = if ($tmpAttrib.Indexed -like "yes") {1} else {0}
  }
 
# Build Object
New-ADObject -Name  $tmpAttrib.Name -Type attributeSchema -Path $schemaPath -OtherAttributes $Attribute
 
# Add to User Schema
$userSchema | Set-ADObject -Add @{mayContain = $tmpAttrib.Name}
}
