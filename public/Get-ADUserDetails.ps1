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
		[string] $Firstname

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
					$filter = "(&(objectCategory=person)(sn=$Surname*)(givenName=$Firstname*))"
				}
				elseif ($Surname) {
					write-verbose "Searching for user accounts with a Surname matching '$Surname'"
					$filter = "(&(objectCategory=person)(sn=$Surname*))"
				}
				elseif ($Firstname) {
					write-verbose "Searching for user accounts with a Firstname matching '$Firstname'"
					$filter = "(&(objectCategory=person)(givenName=$Firstname*))"
				}
				else {
					$abort = $true
					write-warning "Surname or Firstname (or both) parameters must have values"
				}
		}
		elseif ($PSCmdlet.ParameterSetName -eq "Identity") {
			write-verbose "Searching for user accounts with a samAccountName exactly matching '$Identity'"
			$filter = "(&(objectCategory=person)(samAccountName=$Identity))"
		}

		if (!$abort) {
			# search the current domain only
			$dom = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
			$root = $dom.GetDirectoryEntry() 
			$searcher = new-Object System.DirectoryServices.DirectorySearcher
			$searcher.SearchRoot = $root
			$searcher.SearchScope = "Subtree"
			$searcher.Filter = $filter
			$results = $searcher.FindAll() 
        
			If ($results -ne $null) {
				foreach ($result in $results) {
					$currentUser = $result.GetDirectoryEntry()
                    
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

# password expired flag doesn't seem to be supported after Windows 2003.
#					if (($userAccountControl -band $PASSWORD_EXPIRED) -eq $PASSWORD_EXPIRED) {
#						$userPasswordExpired = $true
#					}

					# check to see if the user must change password on next logon
					$pwdChangeOnNextLogon = $false
					if ($currentUser.ConvertLargeIntegerToInt64($currentUser.pwdLastSet[0]) -eq 0) {
						$pwdChangeOnNextLogon = $true
					}
                
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
					}
					$outputObject = New-Object -Property $Result -TypeName psobject
					$outputObject.PSObject.TypeNames.Insert(0, "Powertools.GetADUserDetails.Result")
					write-output $outputObject 
				}
			}
			Else {
				Write-Warning "No matching user found." 
			}
			$searcher.Dispose()
		}
	}
}

