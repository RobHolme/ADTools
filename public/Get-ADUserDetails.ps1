function Get-ADUserDetails() {
	<#
.NOTES
Function Name  : Get-ADUserDetails
Author     : Rob Holme (rob@holme.com.au)  

.SYNOPSIS 
Display the common properties for an AD user account. User Get-ADUser instead if RSAT tools are installed.
.DESCRIPTION 
Display the common properties for an AD user account. User Get-ADUser instead if RSAT tools are installed. 
Intended for systems were user rights do not permit install of AD RSAT tools.
.EXAMPLE 
Get-ADUserDetails -ID Rob
.EXAMPLE
Get-ADUserDetails -ID Rob*
.EXAMPLE
# find all users with exact match of 'Holme' for Surname, with a firstname starting with Rob.
Get-ADUserDetails -Surname Holme -Firstname Rob*
.PARAMETER Identity 
The logon ID (samAccountName) of the AD user account. Will search for exact match unless wildcard modifer '*' included.
.PARAMETER Surname
The user's surname to search for. Will search for exact match unless wildcard modifer '*' included in the Surname string.
.PARAMETER Firstname
The user's firstname to search for. Will search for exact match unless wildcard modifer '*' included in the Firstname string.
.PARAMETER Displayname
The user account's Displayname to search for. Will search for exact match unless wildcard modifer '*' included in the Displayname string.
.PARAMETER EmailAddress
The user's primary SMTP address to search for. Will search for exact match unless wildcard modifer '*' included in the EmailAddress string.
.PARAMETER AllProperties
Display all account properties. 
.LINK
https://github.com/RobHolme/ADTools#get-aduserdetails

#>
	[CmdletBinding(DefaultParameterSetName = "Identity")]
	Param(
		[Parameter(
			Position = 0, 
			Mandatory = $True, 
			ParameterSetName = "Identity",
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[ValidateNotNullOrEmpty()]
		[Alias('ID', 'samAccountName')] 
		[string] $Identity,

		[Parameter(
			Position = 0, 
			Mandatory = $False, 
			ParameterSetName = "Name",
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[Alias('LastName')] 
		[string] $Surname,

		[Parameter(
			Position = 1, 
			Mandatory = $False, 
			ParameterSetName = "Name",
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[Alias('GivenName')] 
		[string] $Firstname,

		[Parameter(
			Position = 0, 
			Mandatory = $False, 
			ParameterSetName = "DisplayName",
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[string] $Displayname,

		[Parameter(
			Position = 0, 
			Mandatory = $False, 
			ParameterSetName = "EmailAddress",
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[string] $EmailAddress,

		# List all properties
		[Parameter(Position = 2, 
			Mandatory = $False
		)]
		[Switch] $AllProperties
	)
    
	begin {
		# bit masks for UserAccountControl attribute (in decimal)
		[int] $ACCOUNTDISABLE = 2
		[int] $DONT_EXPIRE_PASSWORD = 65536

		# confirm the powershell version and platform requirements are met if using powershell core. 
		# ADSI only supported on Windows, and only v6.1+ of Powershell core (or all Windows Powershell versions)
		if ($IsCoreCLR) {
			if (($PSVersionTable.PSVersion -lt 6.1) -or ($PSVersionTable.Platform -ne "Win32NT")) {
				Write-Warning "This function requires Powershell Core 6.1 or greater on Windows."
				$abort = $true
				return
			}
		}
	}
    
	process {
		if ($abort) {
			return
		}

		# construct the LDAP search filter based on the parameter set provided
		switch ($PSCmdlet.ParameterSetName) {
			"Name" {
				if (($Surname) -and ($Firstname)) {
					write-verbose "Searching for user accounts with a Firstname matching '$Firstname' and Surname matching '$Surname'"
					$filter = "(&(sAMAccountType=805306368)(sn=$Surname)(givenName=$Firstname))"
					$searchString = "$Firstname $Surname"
				}
				elseif ($Surname) {
					write-verbose "Searching for user accounts with a Surname matching '$Surname'"
					$filter = "(&(sAMAccountType=805306368)(sn=$Surname))"
					$searchString = "$Surname"
				}
				elseif ($Firstname) {
					write-verbose "Searching for user accounts with a Firstname matching '$Firstname'"
					$filter = "(&(sAMAccountType=805306368)(givenName=$Firstname))"
					$searchString = "$Firstname"
				}
				else {
					$abort = $true
					write-warning "Surname or Firstname (or both) parameters must have values"
				}
			}
			"Displayname" {
				write-verbose "Searching for user accounts with a Displayname starting with '$Surname'"
				$filter = "(&(sAMAccountType=805306368)(displayName=$Displayname))"
				$searchString = "$Displayname"
			}
			"Identity" {
				write-verbose "Searching for user accounts with a samAccountName starting with '$Identity'"
				$filter = "(&(sAMAccountType=805306368)(samAccountName=$Identity))"
				$searchString = "$Identity"
			}
			"EmailAddress" {
				write-verbose "Searching for user accounts with a mail field starting with '$EmailAddress'"
				$filter = "(&(sAMAccountType=805306368)(mail=$EmailAddress))"
				$searchString = "$EmailAddress"
			}
		}

		# search the current domain only
		$dom = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
		$root = $dom.GetDirectoryEntry() 
		$searcher = new-Object System.DirectoryServices.DirectorySearcher
		$searcher.SearchRoot = $root
		$searcher.SearchScope = "Subtree"
		$searcher.Filter = $filter
		$results = $searcher.FindAll() 
		Write-Verbose "Filter: $filter"
		If ($results.Count -gt 0) {
			foreach ($userAccount in $results) {
				$currentUser = $userAccount.GetDirectoryEntry()
										
				# get the account status from the userAccountControl bitmask 
				$userPasswordNeverExpires = $userDisabled = $false
				$userAccountControl = $currentUser.UserAccountControl[0]
				if (($userAccountControl -band $ACCOUNTDISABLE) -eq $ACCOUNTDISABLE) {
					$userDisabled = $true
				}
				if (($userAccountControl -band $DONT_EXPIRE_PASSWORD) -eq $DONT_EXPIRE_PASSWORD) {
					$userPasswordNeverExpires = $true
				}

				# check to see if the user must change password on next logon
				$pwdChangeOnNextLogon = $false
				try {
					if ($currentUser.ConvertLargeIntegerToInt64($currentUser.pwdLastSet[0]) -eq 0) {
						$pwdChangeOnNextLogon = $true
					}
				}
				catch {
					$pwdChangeOnNextLogon = "Unknown"
				}

				# display all account properties if the -AllProperties switch is set
				if ($AllProperties) {
					$Result = [ORDERED] @{ }
					foreach ($key in ($currentUser.Properties.Keys | Sort-Object)) {
						write-verbose "Property: $key"
						# property is a single value
						if (($currentUser.Properties[$key]).Count -le 1) {
							$currentProperty = $currentUser.Properties[$key][0]
							if ($currentProperty.GetType() -eq [System.__ComObject]) {
								# COM objects are usually date time values, but not always. Treating exceptions as unknown formats.
								try {
									$longIntValue = $currentUser.ConvertLargeIntegerToInt64($currentProperty)
									# assuming all AD timestamps will be post Jan 1 1999 (125595936000000000), so if Long Int value is greater assume it's a date, otherwise assume it's a number
									if ($longIntValue -gt 125595936000000000) {
										$datetime = ConvertADDateTime $longIntValue
										$Result.Add($key, $datetime)
									}
									else {
										$Result.Add($key, $longIntValue)
									}
								}
								catch {
									$Result.Add($key, "<Unkown format>")
								}
							}
							elseif ($currentProperty.GetType() -eq [System.Byte[]]) {
								$Result.Add($key, "<byte value>")
							}
							else {
								$Result.Add($key, $currentProperty.ToString())
							}
						}
						# property is an array
						else {
							$currentProperty = $currentUser.Properties[$key]
							$Result.Add($key, $currentProperty)
						}
					}
					$outputObject = New-Object -Property $Result -TypeName psobject
					$outputObject.PSObject.TypeNames.Insert(0, "ADTools.GetADUserDetails.Result.AllProperties")
				}
				# only display short list of common properties
				else {
					# catxh exception if user does not have rights to query AccountExpires or PasswordLastSet attributes
					try {
						$AccountExpires = ConvertADDateTime $currentUser.ConvertLargeIntegerToInt64($currentUser.accountExpires[0])
						$PasswordLastSet = ConvertADDateTime $currentUser.ConvertLargeIntegerToInt64($currentUser.pwdLastSet[0])
					}
					catch {
						$AccountExpires = "Unknown"
						$PasswordLastSet = "Unknown"
					}
					# display the account properties                   
					$Result = @{
						samAccountName            = $currentUser.samAccountName.ToString()
						UserPrincipalName         = $currentUser.userPrincipalName.ToString()
						DisplayName               = $currentUser.displayName.ToString()
						GivenName				  = $currentUser.givenName.ToString()
						Surname                   = $currentUser.sn.ToString()
						Company                   = $currentUser.company.ToString()
						Department				  = $currentUser.department.ToString()
						Location				  = $currentUser.location.ToString()
						PhoneNumber               = $currentUser.telephoneNumber.ToString()
						Mobile                    = $currentUser.mobile.ToString()
						OtherIpPhone              = $currentUser.otherIpPhone.ToString()
						AccountDisabled           = $userDisabled 
						AccountLocked             = $currentUser.IsAccountLocked
						PasswordNeverExpires      = $userPasswordNeverExpires
						AccountExpires            = $AccountExpires
						PasswordLastSet           = $PasswordLastSet
						ChangePasswordOnNextLogon = $pwdChangeOnNextLogon
						DN                        = $currentUser.distinguishedName[0]
					}
					$Result = $Result | Sort-Object
					$outputObject = New-Object -Property $Result -TypeName psobject
					$outputObject.PSObject.TypeNames.Insert(0, "ADTools.GetADUserDetails.Result")
				}
				write-output $outputObject 
			}
		}
		Else {
			Write-Warning "No matching user found for $searchString" 
		}
		$searcher.Dispose()
	}
}


