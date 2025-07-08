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
.PARAMETER SiteName
Only show logons from domain controllers from the nominated site.
.PARAMETER Timeout
Set a timeout for the Domain Controller to respond. Defaults to 3 seconds. Max 20 seconds.
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
		[Alias('ID', 'samAccountName')] 
		[string] $Identity,

		# set a timeout for the Domain Controller to respond. Defaults to 3 seconds. Max 20 seconds.
		[Parameter(
			Mandatory = $false
		)]
		[ValidateRange(1, 20)]
		[int] $timeout = 3,

		# limit search to a specific AD site
		[Parameter(
			Mandatory = $false
		)]
		[string] $SiteName
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

		# get the domain name
		try {
			$dom = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
			$domain = [ADSI]"LDAP://$dom"
		}
		catch {
			Write-Error "Unable to connect to the Active Directory Domain. Use -Debug for more information."
			Write-Debug "Exception thrown connecting to the domain: $($_.Exception.Message)"
			$abort = $True
			return
		}

		# get the domain controllers from the nominated site name, or the entire domain if no site name is specified
		if ($SiteName) {
			try {
				$forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
				$forestType = [System.DirectoryServices.ActiveDirectory.DirectoryContexttype]"forest"
				$forestContext = New-Object -TypeName System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList $forestType, $forest				
				$domainControllers = ([System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::FindByName($forestContext, $SiteName)).Servers
			}
			Catch {
				write-error "Unable to find site $SiteName"
				$abort = $True
				return
			}
		}
		# get the domain controllers for the entire domain
		else {
			$domainControllers = $dom.DomainControllers
		}

		# keep a list of domain controllers that can not be contacted, do not attempt to connect again if multiple logoin IDs supplied vai the pipeline. Saves time for larger searches. 
		$uncontactableDomainControllers = @()
	}

	process {
		if ($abort) {
			return
		}

		write-verbose "Searching for user accounts with a samAccountName starting with '$Identity'"
		$searcher = new-Object System.DirectoryServices.DirectorySearcher
		
		# Set search to async. Set timeout.
		$searcher.Asynchronous = $true
		$searcher.ClientTimeout = "00:00:$Timeout"
		
		# Set search scope, filter,  and properties to return
		$searcher.SearchScope = "Subtree"
		$filter = "(&(sAMAccountType=805306368)(samAccountName=$Identity))"
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
			if ($uncontactableDomainControllers -contains $domainController) {
				Write-Warning "Skipping $domainController"
				continue
			}
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
			# catch exceptions if a domain controller can not be contacted
			catch {
				Write-Debug "Exception thrown connecting to $domainController : $($_.Exception.Message)"
				Write-Warning "Unable to connect to $domainController. Use -Debug switch to view exception message"
				$uncontactableDomainControllers += $domainController
				continue
			}
		}
		$searcher.Dispose()
	}
}
