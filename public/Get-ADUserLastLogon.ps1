function Get-ADUserLastLogon() {
	<#
.NOTES
Function Name  : Get-ADUserDetails
Author     : Rob Holme (rob@holme.com.au)  

.SYNOPSIS 
Display the last logon timestamp for a user account
.DESCRIPTION 
Display the last logon timestamp for a user account. Optionally show the last logon timestamp each DC.
.EXAMPLE 
Get-ADUserLastLogon -Identity Rob
.EXAMPLE
Get-ADUserLastLogon -Identity Rob -ShowAllDomainControllers
.EXAMPLE
Get-ADUserLastLogon -Identity Rob -Site west-coast
.PARAMETER Identity 
The logon ID (samAccountName) of the AD user account. Partial matches will be returned.
.PARAMETER SiteName
Only show logons from domain controllers from the nominated site. 
.PARAMETER ShowAllDomainControllers
Show the logon times reported by each Domain Controller.
.LINK
https://github.com/RobHolme/ADTools#get-aduserlastlogon
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

		# switch to show logons for all DCs in the domain
		[Parameter()]
		[Switch] $ShowAllDomainControllers,

		# limit search to a specific AD site
		[Parameter(
			Mandatory = $false
		)]
		[string] $SiteName,

		# set a timeout for the Domain Controller to respond. Defaults to 3 seconds. Max 20 seconds.
		[Parameter(
			Mandatory = $false
		)]
		[ValidateRange(1, 20)]
		[int] $Timeout = 3
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

		# construct the LDAP search filter
		write-verbose "Searching for user accounts with a samAccountName starting with '$Identity'"
		$searcher = new-Object System.DirectoryServices.DirectorySearcher
		
		# Set search to async. Set timeout.
		$searcher.Asynchronous = $true
		$searcher.ClientTimeout = "00:00:$Timeout"
		
		# Set search scope, filter, and properties to return
		$searcher.SearchScope = "Subtree"
		$filter = "(&(sAMAccountType=805306368)(samAccountName=$Identity))"
		$searcher.Filter = $filter
		$searcher.PropertiesToLoad.Add("displayName") > $Null
		$searcher.PropertiesToLoad.Add("sAMAccountName") > $Null
		$searcher.PropertiesToLoad.Add("logonCount") > $Null
		$searcher.PropertiesToLoad.Add("lastLogon") > $Null
		Write-Verbose "Filter: $filter"
		
		# search each domain controller, save the last logon time if is the most recent
		$latestLogon = @{ }
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
						# Retrieve the values.
						$userAccount = $result.GetDirectoryEntry()

						# confirm user has rights to query the user's properties.
						if ($null -eq $userAccount.pwdLastSet[0]) {
							Write-Warning "Insufficient rights to query all user account properties for $($userAccount.distinguishedName)."
							Write-Warning "This module assumes authenticated users have 'built-in\pre-Windows 2000 compatible access' membership, otherwise use a privileged account."
							return
						}
						
						$samAccountName = $userAccount.samAccountName.ToString()
						if ($null -eq $userAccount.lastLogon[0]) {
							$lastLogon = 0
						}
						else {
							$lastLogon = $userAccount.ConvertLargeIntegerToInt64($userAccount.lastLogon[0])
						}

						# if the -ShowAllDomainControllers parameter is set, show logons recorded on all domain controllers
						if ($ShowAllDomainControllers) {
							[PSCustomObject]@{
								PSTypeName       = "ADTools.GetADUserLastLogon.Result"
								LogonID          = $samAccountName
								DisplayName      = $userAccount.displayName.ToString()
								LastLogon        = ConvertADDateTime $lastLogon
								LogonCount       = $userAccount.logonCount.ToString()
								DomainController = GetShortHostname $domainController.Name
								Site             = $domainController.SiteName
							}

						}
						# record only the most recent logon if -ShowAllDominControllers is not set
						else {
							# store the most recent logon for each user object
							if ($latestLogon[$samAccountName].logonTime -lt $lastLogon) {
								$latestLogon[$samAccountName] = @{
									displayName      = $userAccount.displayName.ToString()
									domainController = $domainController.Name
									site             = $domainController.SiteName
									logonTime        = $lastLogon
									logonCount       = $userAccount.logonCount.ToString()
								}
							}
						}
					}
				}
			}
			# catch exceptions if a domain controller can not be contacted
			catch {
				Write-Debug "Exception thrown connecting to $domainController : $($_.Exception.Message)"
				Write-Warning "Unable to connect to $domainController"
				$uncontactableDomainControllers += $domainController
				continue
			}
		}
		# if the -ShowAllDomainControllers parameter is not set, only show the latest logon
		if (!$ShowAllDomainControllers) {
			# return the results to pipeline
			foreach ($key in $latestLogon.Keys) {
				[PSCustomObject]@{
					PSTypeName       = "ADTools.GetADUserLastLogon.Result"
					LogonID          = $key
					DisplayName      = $latestLogon[$key].displayName
					LastLogon        = ConvertADDateTime $latestLogon[$key].logonTime
					LogonCount       = $latestLogon[$key].logonCount
					DomainController = $(if ($latestLogon[$key].logonTime -ne 0) { GetShortHostname $latestLogon[$key].domainController })
					Site             = $(if ($latestLogon[$key].logonTime -ne 0) { $latestLogon[$key].site })
				}
			}
		}
		$searcher.Dispose()
	}
}

