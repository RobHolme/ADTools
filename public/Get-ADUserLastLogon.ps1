function Get-ADUserLastLogon() {
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
Get-ADUserDetails -Identity Rob
.EXAMPLE
Get-ADUserDetails -Identity Rob -ShowAllDomainControllers
.EXAMPLE
Get-ADUserDetails -Identity Rob -Site west-coast
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
		[Alias('ID')] 
		[string] $Identity,

		# switch to show logons for all DCs in the domain
		[Parameter()]
		[Switch] $ShowAllDomainControllers,

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
		
		# get the domain controllers from the nominated site name
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
		$searcher.PropertiesToLoad.Add("logonCount") > $Null
		$searcher.PropertiesToLoad.Add("lastLogon") > $Null
		Write-Verbose "Filter: $filter"
		
		# search each domain controller, save the last logon time if is the most recent
		$latestLogon = @{}
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
						# Retrieve the values.
						$userAccount = $result.GetDirectoryEntry()
						$samAccountName = $userAccount.samAccountName.ToString()
						if ($null -eq $userAccount.lastLogon[0]) {
							$lastLogon = 0
						}
						else {
							$lastLogon = $userAccount.ConvertLargeIntegerToInt64($userAccount.lastLogon[0])
						}

						# if the -ShowAllDomainControllers parameter is set, show logons recorded on all domain controllers
						if ($ShowAllDomainControllers) {
							$resultObject = [ORDERED] @{
								LogonID          = $samAccountName
								DisplayName      = $userAccount.displayName.ToString()
								LastLogon        = ConvertADDateTime $lastLogon
								LogonCount       = $userAccount.logonCount.ToString()
								DomainController = $domainController.Name
							}
							$outputObject = New-Object -Property $resultObject -TypeName psobject
							$outputObject.PSObject.TypeNames.Insert(0, "ADTools.GetADUserLastLogon.Result")
							write-output $outputObject 
						}
						# record only the most recent logon if -ShowAllDominControllers is not set
						else {
							# store the most recent logon for each user object
							if ($latestLogon[$samAccountName].logonTime -lt $lastLogon) {
								$latestLogon[$samAccountName] = @{
									displayName      = $userAccount.displayName.ToString()
									domainController = $domainController.Name
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
				continue
			}
		}
		# if the -ShowAllDomainControllers parameter is not set, only show the latest logon
		if (!$ShowAllDomainControllers) {
			# return the results to pipeline
			foreach ($key in $latestLogon.Keys) {
				$resultObject = [ORDERED] @{
					LogonID          = $key
					DisplayName      = $latestLogon[$key].displayName
					LastLogon        = ConvertADDateTime $latestLogon[$key].logonTime
					LogonCount       = $latestLogon[$key].logonCount
					DomainController = $latestLogon[$key].domainController
				}
				$outputObject = New-Object -Property $resultObject -TypeName psobject
				$outputObject.PSObject.TypeNames.Insert(0, "ADTools.GetADUserLastLogon.Result")
				write-output $outputObject 
			}
		}
		$searcher.Dispose()
	}
}

