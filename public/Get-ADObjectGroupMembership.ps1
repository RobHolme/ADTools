function Get-ADObjectGroupMembership() {
	<#
.NOTES
Function Name  	: Get-ADObjectGroupMembership
Author     		: Rob Holme (rob@holme.com.au)  

.SYNOPSIS 
Display the group membership for an AD object.
.DESCRIPTION 
Display the group membership for an AD object. Use Get-ADPrincipalGroupMembership instead if AD powershell module is installed.
.EXAMPLE 
Get-ADObjectGroupMembership -ID Rob
.PARAMETER Identity 
The CN of the AD Object account 
.LINK
https://github.com/RobHolme/ADTools#get-adobjectgroupmembership
#>
	[CmdletBinding()]
	Param(
		[Parameter(
			Position = 0, 
			Mandatory = $True, 
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[ValidateNotNullOrEmpty()]
		[Alias('ID','samAccountName')] 
		[string] $Identity,
		
		[Parameter(
			Position = 1, 
			Mandatory = $False 
		)] 
		[ValidateSet("User", "Computer", "Group", "Contact")]
		[string] $ObjectType = "User"
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
		
		# set default value if ObjectType not specified
		if (!$ObjectType) {
			$ObjectType = "User"
			Write-Warning "ObjectType not set, defaulting to searching User objects"
		}
	}
    
	process {

		if (!$abort) {
			# search the current domain only
			$dom = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
			$root = $dom.GetDirectoryEntry() 
			$searcher = new-Object System.DirectoryServices.DirectorySearcher
			$searcher.SearchRoot = $root
			$searcher.SearchScope = "Subtree"
			
			# construct the search filter based on object type
			switch ($ObjectType) {
				"Computer" { 
					Write-Verbose "Searching computer objects matching '$Identity'."
					$searcher.Filter = "(&(objectCategory=computer)(name=$Identity))"
				}
				"Group" {
					Write-Verbose "Searching group objects matching '$Identity'."
					$searcher.Filter = "(&(objectCategory=group)(name=$Identity))"
				}
				"User" {
					Write-Verbose "Searching user objects matching '$Identity'."
					$searcher.Filter = "(&(sAMAccountType=805306368)(objectClass=user)(samAccountName=$Identity))"
				}
				"Contact" {
					Write-Verbose "Searching contact objects matching '$Identity'."
					$searcher.Filter = "(&(objectClass=contact)(name=$Identity))"
				}
				Default {
					Write-Verbose "Defaulting to searching user objects matching '$Identity'."
					$searcher.Filter = "(&(sAMAccountType=805306368)(objectClass=user)(samAccountName=$Identity))"
				}
			}
		
			$searchResults = $searcher.FindAll() 
			if ($searchResults.Count -eq 0) {
				write-warning "No AD user, group, computer, or contact object for $Identity found."
			}
			else {
				foreach ($adObject in $searchResults) {
					$currentObject = $adObject.GetDirectoryEntry()
					$groups = $currentObject.memberOf
					if ($groups.Count -eq 0) {
							Write-Warning "The object $Identity is not a member of any groups"
					}
					else {
						foreach ($group in $groups) {
							try {
								$groupDetails = [ADSI] "LDAP://$group" 
								$groupType = GetGroupType ([convert]::ToInt32($groupDetails.Properties.grouptype, 10))
								
								# display the properties of each group              
								[PSCustomObject]@{
									PSTypeName        = "ADTools.GetADObjectGroupMembership.Result"
									samAccountName    = $currentObject.samAccountName[0]
									GroupName         = $($groupDetails.Properties.name).ToString()
									GroupType         = $groupType
									distinguishedName = $group
								}
							}
							catch {
								Write-Debug "Exception thrown when accessing LDAP://$group : $($_.Exception.Message)"
								Write-Warning "error accessing LDAP://$group"
							}
						}
					}
				}
			}
			$searcher.Dispose()
		}
	}
}


