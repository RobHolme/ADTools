function Find-ADGroup() {
	<#
.NOTES
Function Name  : Find-ADGroup
Author     : Rob Holme (rob@holme.com.au)  

.SYNOPSIS 
Searches for groups matching a name
.DESCRIPTION 
Searches for groups matching a name
.EXAMPLE 
Find-ADGroup -Name VPN
.PARAMETER Identity 
The name AD user group 
.LINK
https://github.com/RobHolme/ADTools#find-adgroup
#>
	[CmdletBinding()]
	Param(
		[Parameter(
			Position = 0, 
			Mandatory = $True, 
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[ValidateNotNullOrEmpty()]
		[string] $Name

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
	}

	process {
		if (!$abort) {
			$searcher = new-object System.DirectoryServices.DirectorySearcher   
			$filter = "(&(objectClass=group)(name=$Name))"
			$searcher.PageSize = 1000
			$searcher.Filter = $filter
			$searchResult = $searcher.FindAll()

			if ($searchResult.Count -eq 0) {
				write-warning "No matching groups found"
			}
			else {
				foreach ($group in $searchResult) {
					# determine the type of group
					$groupType = GetGroupType ([convert]::ToInt32($group.Properties.grouptype, 10))

					# display the properties of each group              
					[PSCustomObject]@{
						PSTypeName        = "ADTools.FindADGroup.Result"
						Name              = $($group.Properties.name).ToString()
						GroupType         = $groupType
						distinguishedName = ($group.Path) -replace "LDAP://"
					}
				}
				$searcher.Dispose()
			}
		}
	}
}


