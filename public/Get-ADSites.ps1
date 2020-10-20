function Get-ADSites {
	<#
	.SYNOPSIS
		List all Active Directory sites in the forest.
	.DESCRIPTION
		List all Active Directory sites in the forest.
	.PARAMETER CurrentSiteOnly
		Show only the site details that the workstation belongs to.
	.EXAMPLE
		Get-ADSites
	.EXAMPLE
		Get-ADSites -CurrentSite
	#>

	[CmdletBinding()]
	Param (
		# switch to show the current site only
		[Parameter(Mandatory = $false)]
		[switch] $CurrentSite
	)

	# confirm the powershell version and platform requirements are met if using powershell core. 
	# ADSI only supported on Windows, and only v6.1+ of Powershell core (or all Windows Powershell versions)
	if ($IsCoreCLR) {
		if (($PSVersionTable.PSVersion -lt 6.1) -or ($PSVersionTable.Platform -ne "Win32NT")) {
			Write-Warning "This function requires Powershell Core 6.1 or greater on Windows."
			$abort = $true
			return
		}
	}

	# Get details of the site the workstation is a member of
	if ($CurrentSite) {
		$siteInfo = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite()
	}
	# Get all sites
	else {
		$siteInfo = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites
	}
	# write the results to the pipeline
	foreach ($site in $siteInfo) {
		$resultObject = [ORDERED] @{
			SiteName = $site.Name
			Servers  = $site.Servers
			Subnet   = $site.Subnets
		}
		$outputObject = New-Object -Property $resultObject -TypeName psobject
		$outputObject.PSObject.TypeNames.Insert(0, "ADTools.GetADSites.Result")
		write-output $outputObject 
	}
}
	
