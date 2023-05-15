<#
Add additional columns to Active Directory Users and Computers snap-in.

THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED “AS IS” WITHOUT WARRANTY 
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR RESULTS FROM THE USE OF 
THIS CODE REMAINS WITH THE USER.

Author: Aaron Guilmette
		aaron.guilmette@microsoft.com
#>

<#
.SYNOPSIS
Add ability to view additional attributes as columns in Active Directory
Users and Computers MMC Snap-In.

.DESCRIPTION
Extend the Active Directory Users and Computers MMC Snap-In with
additional attributes.

.PARAMETER Visibility
Configure whether or not this attribute will be visible by default.

.PARAMETER ColumnWidth
Determines the width of the new column. Values are -1-255. -1 is Auto.

.PARAMETER Language
Select language of display specifier to modify. Default is English.

.PARAMETER NewAttribute
Name of new attribute to add.

.PARAMETER Title
Column title. If not specified, will use attribute name.

.EXAMPLE
Add-ADUCAttribute.ps1 -NewAttribute extensionAttribute1

.EXAMPLE
Add-ADUCAttribute.ps1 -NewAttribute extensionAttribute1 -Title "Extension Attribute 1"

.LINK
https://gallery.technet.microsoft.com/Extend-Active-Directory-ccad3d1a
#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False,HelpMessage='Column is visible by default in ADUC')]
	[ValidateSet("0","1")]
	$Visibility = 1,

	[Parameter(Mandatory=$False,HelpMessage='Column width')]
	[ValidateRange("-1","255")]
	$Width = -1,

	[Parameter(Mandatory=$False,HelpMessage='Language code (US [409] is default)')]
	[ValidateSet("401","404","405","406","407","408","409","40B","40C","40D","40E","410","411","412","413","414","415","416","419","41D","41F","804","816","C04","C0A")]
    $Language = 409,

    [Parameter(Mandatory=$False,HelpMessage='Column title or description')]
    $Title,

	[Parameter(Mandatory=$True,HelpMessage='Attribute to add as column')]
	[String]$NewAttribute
	)

Import-Module ActiveDirectory
$Reserved = 0

If (!($Title))
    {
    $Title = $NewAttribute
    }

$Config = (Get-ADRootDSE).configurationNamingContext
$ouDisplaySpecifier = Get-ADObject -Identity "CN=organizationalUnit-Display,CN=$Language,CN=DisplaySpecifiers,$Config" -Properties *
$defaultDisplaySpecifier = Get-ADObject -Identity "CN=default-Display,CN=$Language,CN=DisplaySpecifiers,$config" -Properties *

If ($ouDisplaySpecifier.extraColumns.Count -ge 1) 
	{ 
    Write-Host -ForegroundColor Cyan "organizationalUnit-Display specifiers already has values. Adding new attribute to existing values."
    $extraColumns = $ouDisplaySpecifier.extraColumns
    Write-Host -ForegroundColor DarkCyan "Existing contents are: $($extraColumns)"
    } 
else
	{
    Write-Host -ForegroundColor Yellow "extraColumns attribute is currently empty. Importing default-Display specifier values." 
    $extraColumns += $defaultDisplaySpecifier.extraColumns
    }


$NewAttribute = $NewAttribute + "," + $Title + ",$Visibility,$Width,$Reserved"
$extraColumns += $NewAttribute
Write-Host -ForegroundColor Green "Updating OU Display Specifiers with $($NewAttribute)."
Set-ADObject $ouDisplaySpecifier -Replace @{extraColumns=$extraColumns}