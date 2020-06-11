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
#>
	[CmdletBinding()]
	Param(
		[Parameter(
			Position = 0, 
			Mandatory = $True, 
			ValueFromPipeline = $True, 
			ValueFromPipelineByPropertyName = $True)] 
		[ValidateNotNullOrEmpty()]
		[Alias('ID')] 
		[string] $Identity,
		
		[Parameter(
			Position = 1, 
			Mandatory = $True 
		)] 
		[ValidateSet("User", "Computer", "Group", "Contact")]
		[string] $ObjectType
	)
    
	begin {
		# confirm the powershell version and platform requirements are met if using powershell core
		if ($IsCoreCLR) {
			if (($PSVersionTable.PSVersion -lt 6.1) -or ($PSVersionTable.Platform -ne "Win32NT")) {
				Write-Warning "This function requires Powershell Core 6.1 or greater on Windows."
				$abort = $true
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
			if ($ObjectType -eq "Computer") {
				Write-Verbose "Searching computer objects matching '$Identity'."
				$searcher.Filter = "(&(objectCategory=computer)(name=$Identity))"
			}
			if ($ObjectType -eq "Group") {
				Write-Verbose "Searching group objects matching '$Identity'."
				$searcher.Filter = "(&(objectCategory=group)(name=$Identity))"
			}
			if ($ObjectType -eq "User") {
				Write-Verbose "Searching user objects matching '$Identity'."
				$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(samAccountName=$Identity))"
			}
			if ($ObjectType -eq "Contact") {
				Write-Verbose "Searching contact objects matching '$Identity'."
				$searcher.Filter = "(&(objectClass=contact)(name=$Identity))"
			}
			$searchResult = $searcher.FindOne() 

			If ($searchResult) {
				$currentObject = $searchResult.GetDirectoryEntry()
				$groups = $currentObject.memberOf
				foreach ($group in $groups) {
					try {
						$groupDetails = [ADSI] "LDAP://$group" 
						$groupType = GetGroupType ([convert]::ToInt32($groupDetails.Properties.grouptype, 10))
						
						# display the properties of each group              
						$result = [ORDERED]@{
							samAccountName    = $Identity
							GroupName         = $($groupDetails.Properties.name).ToString()
							GroupType         = $groupType
							distinguishedName = $group
						}
						$outputObject = New-Object -Property $Result -TypeName psobject
						$outputObject.PSObject.TypeNames.Insert(0, "Powertools.GetADObjectGroupMembership.Result")
						write-output $outputObject 
					}
					catch {
						Write-Warning "error accessing LDAP://$group"
					}
				}
			}
			else {
				write-warning "No $ObjectType object matching '$Identity' found."
			}
			$searcher.Dispose()
		}
	}
}


