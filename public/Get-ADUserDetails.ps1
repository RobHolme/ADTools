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
.PARAMETER Identity 
The logon ID (samAccountName) of the AD user account 
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
		[Alias('ID')] 
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

		# List all properties
		[Parameter(Position = 2, 
			Mandatory = $False
		)]
		[Switch] $AllProperties
	)
    
	begin {
		# bit masks for UserAccountControl attribute (in decimal)
		[int] $ACCOUNTDISABLE = 2
		[int] $LOCKOUT = 16
		#		[int] $PASSWORD_EXPIRED = 8388608
		[int] $DONT_EXPIRE_PASSWORD = 65536

		# confirm the powershell version and platform requirements are met if using powershell core
		if ($IsCoreCLR) {
			if (($PSVersionTable.PSVersion -lt 6.1) -or ($PSVersionTable.Platform -ne "Win32NT")) {
				Write-Warning "This function requires Powershell Core 6.1 or greater on Windows."
				$abort = $true
			}
		}
	}
    
	process {

		if ($PSCmdlet.ParameterSetName -eq "Name") {
			if (($Surname) -and ($Firstname)) {
				write-verbose "Searching for user accounts with a Firstname matching '$Firstname' and Surname matching '$Surname'"
				$filter = "(&(sAMAccountType=805306368)(sn=$Surname*)(givenName=$Firstname*))"
			}
			elseif ($Surname) {
				write-verbose "Searching for user accounts with a Surname matching '$Surname'"
				$filter = "(&(sAMAccountType=805306368)(sn=$Surname*))"
			}
			elseif ($Firstname) {
				write-verbose "Searching for user accounts with a Firstname matching '$Firstname'"
				$filter = "(&(sAMAccountType=805306368)(givenName=$Firstname*))"
			}
			else {
				$abort = $true
				write-warning "Surname or Firstname (or both) parameters must have values"
			}
		}
		elseif ($PSCmdlet.ParameterSetName -eq "Identity") {
			write-verbose "Searching for user accounts with a samAccountName exactly matching '$Identity'"
			$filter = "(&(sAMAccountType=805306368)(samAccountName=$Identity))"
		}

		if ($abort) {
			return
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
		If ($null -ne $results) {
			foreach ($userAccount in $results) {
				$currentUser = $userAccount.GetDirectoryEntry()
										
				# get the account status from the userAccountControl bitmask 
				$userPasswordNeverExpires = $userLockedOut = $userDisabled = $false
				$userAccountControl = $currentUser.UserAccountControl[0]
				if (($userAccountControl -band $ACCOUNTDISABLE) -eq $ACCOUNTDISABLE) {
					$userDisabled = $true
				}
				if (($userAccountControl -band $LOCKOUT) -eq $LOCKOUT) {
					$userLockedOut = $true
				}
				if (($userAccountControl -band $DONT_EXPIRE_PASSWORD) -eq $DONT_EXPIRE_PASSWORD) {
					$userPasswordNeverExpires = $true
				}

				# check to see if the user must change password on next logon
				$pwdChangeOnNextLogon = $false
				if ($currentUser.ConvertLargeIntegerToInt64($currentUser.pwdLastSet[0]) -eq 0) {
					$pwdChangeOnNextLogon = $true
				}

				# display all account properties if the -AllProperties switch is set
				if ($AllProperties) {
					$Result = [ORDERED] @{ }
					foreach ($key in ($currentUser.Properties.Keys | Sort-Object)) {
						write-verbose "Property: $key"
						if (($currentUser.Properties[$key]).Count -le 1) {
							$currentProperty = $currentUser.Properties[$key][0]
							if ($currentProperty.GetType() -eq [System.__ComObject]) {
								# COM objects are usually date time values, but not always. Treating exceptions as unknown formats.
								try {
									# msExchangeVersion appears as a date time, but isn't so don't convert. 
									if ($key -eq "msExchVersion") {
										$Result.Add($key, "<Unkown format>")
									}
									# treat uSNChanged & usnCreated as long int
									elseif (("uSNChanged","usnCreated") -contains $key) {
										$datetime = $currentUser.ConvertLargeIntegerToInt64($currentProperty)
										$Result.Add($key, $datetime)
									}
									# otherwise convert all COMOBject types to a date time
									else {
										$datetime = ConvertADDateTime $currentUser.ConvertLargeIntegerToInt64($currentProperty)
										$Result.Add($key, $datetime)
									}
								}
								catch {
									$Result.Add($key, "<Unkown format>")
								}
							}
							elseif ($currentProperty.GetType() -eq [System.Byte[]]) {
								$Result.Add($key, [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::Unicode.GetBytes($currentProperty)))
							}
							else {
								$Result.Add($key, $currentProperty.ToString())
							}
						}
						else {
							$currentProperty = $currentUser.Properties[$key]
							$Result.Add($key, $currentProperty)
						}
					}
					$outputObject = New-Object -Property $Result -TypeName psobject
					$outputObject.PSObject.TypeNames.Insert(0, "Powertools.GetADUserDetails.Result.AllProperties")
				}
				# only display short list of common properties
				else {
					# display the account properties                   
					$Result = @{
						LogonID                   = $currentUser.samAccountName.ToString()
						DisplayName               = $currentUser.displayName.ToString()
						Title                     = $currentUser.title.ToString()
						PhoneNumber               = $currentUser.telephoneNumber.ToString()
						Mobile                    = $currentUser.mobile.ToString()
						OtherIpPhone              = $currentUser.otherIpPhone.ToString()
						AccountDisabled           = $userDisabled 
						AccountLockout            = $userLockedOut
						PasswordNeverExpires      = $userPasswordNeverExpires
						AccountExpires            = ConvertADDateTime $currentUser.ConvertLargeIntegerToInt64($currentUser.accountExpires[0])
						PasswordLastSet           = ConvertADDateTime $currentUser.ConvertLargeIntegerToInt64($currentUser.pwdLastSet[0])
						ChangePasswordOnNextLogon = $pwdChangeOnNextLogon
						DN                        = $currentUser.distinguishedName[0]
					}
					$Result = $Result | Sort-Object
					$outputObject = New-Object -Property $Result -TypeName psobject
					$outputObject.PSObject.TypeNames.Insert(0, "Powertools.GetADUserDetails.Result")
				}
				write-output $outputObject 
			}
		}
		Else {
			Write-Warning "No matching user found." 
		}
		$searcher.Dispose()
	}
}


