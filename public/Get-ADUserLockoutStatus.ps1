function Get-ADUserLockoutStatus() {
	<#
.NOTES
Function Name  : Get-ADUserLockoutStatus
Author     : Rob Holme (rob@holme.com.au)  

.SYNOPSIS 
Displays the account lockout status for a user on each DC.
.DESCRIPTION 
Displays the account lockout status for a user on each DC.
.EXAMPLE 
Get-ADUserLockoutStatus -Identity Rob
.PARAMETER Identity 
The logon ID (samAccountName) of the AD user account. Partial matches will be returned.
.LINK
https://github.com/RobHolme/ADTools#get-aduserlockoutStatus
#>

	[CmdletBinding()]
	Param(
		# the account identity to search for (samAccountName)
		[Parameter(
			Position = 0, 
			Mandatory = $True, 
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[ValidateNotNullOrEmpty()]
		[Alias('ID','samAccountName')] 
		[string] $Identity
	)
    
	begin {
		# confirm the powershell version and platform requirements are met if using powershell core. 
		# ADSI only supported on Windows, and only v6.1+ of Powershell core (or all Windows Powershell versions)
		if ($IsCoreCLR) {
			if (($PSVersionTable.PSVersion -lt 6.1) -or ($PSVersionTable.Platform -ne "Win32NT")) {
				Write-Warning "This function requires Powershell Core 6.1 or greater on Windows."
				$abort = $true
				return
			}
		}

		# get the current domain
		try {
			$dom = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
			$domain = [ADSI]"LDAP://$dom"
		}
		catch {
			write-error "Unable to connect to the Active Directory Domain"
			$abort = $True
			return
		}

		# get the domain controllers for the entire domain
		$domainControllers = $dom.DomainControllers
	}

	process {
		if ($abort) {
			return
		}

		# construct the LDAP search filter
		write-verbose "Searching for user accounts with a samAccountName starting with '$Identity'"
		$filter = "(&(sAMAccountType=805306368)(samAccountName=$Identity))"

		$searcher = new-Object System.DirectoryServices.DirectorySearcher
		$searcher.SearchScope = "Subtree"
		$searcher.Filter = $filter
		$searcher.PropertiesToLoad.Add("displayName") > $Null
		$searcher.PropertiesToLoad.Add("sAMAccountName") > $Null
		$searcher.PropertiesToLoad.Add("badPwdCount") > $Null
		$searcher.PropertiesToLoad.Add("badPasswordTime") > $Null
		$searcher.PropertiesToLoad.Add("lockoutTime") > $Null
		$searcher.PropertiesToLoad.Add("IsAccountLocked") > $Null
		Write-Verbose "Filter: $filter"
		
		# search each domain controller, save the last logon time if is the most recent
		$progress = 1
		foreach ($domainController in $domainControllers) {
			Write-Verbose "Searching on $domainController"
			$server = $domainController.Name
			write-progress -Activity "Polling domain controllers" -Status $server -PercentComplete (($progress++ / $domainControllers.Count) * 100)
			$results = $Null
			$searchBase = "LDAP://$server/" + $domain.distinguishedName
			$searcher.SearchRoot = $searchBase
			try {
				$results = $searcher.FindAll()
				if ($results) {
					foreach ($result in $results) {
						$userAccount = $result.GetDirectoryEntry()

						# confirm user has rights to query the user's properties.
						if ($null -eq $userAccount.pwdLastSet[0]) {
							Write-Warning "Insufficient rights to query all user account properties for $($userAccount.distinguishedName)."
							Write-Warning "This module assumes authenticated users have 'built-in\pre-Windows 2000 compatible access' membership, otherwise use a privileged account."
							return
						}
						
						$samAccountName = $userAccount.samAccountName.ToString()
						$accountState = "Unlocked"
						if ($userAccount.IsAccountLocked) {
							$accountState = "Locked"
						}
						if ($Null -eq $userAccount.lockoutTime[0]) {
							$lockoutTime = "N/A"
						}
						else {
							# if no timestamp, change to N/A, instead of Never returned by ConvertADDateTime (never may be misleading)
							$lockoutTime = ConvertADDateTime $userAccount.ConvertLargeIntegerToInt64($userAccount.lockoutTime[0])
							if ($lockoutTime -eq "Never") {
								$lockoutTime = "N/A"
							}
						}

						if ($Null -eq $userAccount.badPasswordTime[0]) {
							$badPasswordTime = 0
						}
						else {
							$badPasswordTime = $userAccount.ConvertLargeIntegerToInt64($userAccount.badPasswordTime[0])
						}

						[PSCustomObject]@{
							PSTypeName       = "ADTools.GetADUserLockoutStatus.Result"
							LogonID          = $samAccountName
							DisplayName      = $userAccount.displayName.ToString()
							LockoutStatus    = $accountState
							LockoutTime      = $lockoutTime
							BadPwdCount      = $userAccount.badPwdCount[0]
							LastBadPassword  = ConvertADDateTime $badPasswordTime
							DomainController = $domainController.Name
							Site             = $domainController.SiteName
						}
					}
				}
			}
			catch {
				Write-Debug "Exception thrown connecting to $domainController : $($_.Exception.Message)"
				Write-Warning "Unable to connect to $domainController. Use -Debug switch to view exception message"
				continue
			}
		}
		$searcher.Dispose()
	}
}