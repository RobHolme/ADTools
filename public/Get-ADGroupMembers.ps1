function Get-ADGroupMembers() {
	<#
.NOTES
Function Name  : Get-ADGroupMembers
Author     : Rob Holme (rob@holme.com.au)  

.SYNOPSIS 
Display the members of an active directory group
.DESCRIPTION 
Display the members of an active directory group
.EXAMPLE 
Get-ADGroupMembers -Name "VPN Users"
.EXAMPLE 
Get-ADGroupMembers -Name "VPN*"
.EXAMPLE 
"VPN Users", "RDP Users" | Get-ADGroupMembers
.PARAMETER Identity 
The name AD user group 
.LINK
https://github.com/RobHolme/ADTools#get-adgroupmembers
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
			$filter = "(&(objectClass=group)(cn=${Name}))"
			$searcher.PageSize = 1000
			$searcher.Filter = $filter
			$groups = $searcher.FindAll()

			if ($groups.Count -eq 0) {
				write-warning "No group matching '$Name' found"
				return
			}

			# find each matching group
			foreach ($group in $groups) {
				write-verbose "group membership of $($group.Properties.name)"
				$members = $group.properties.item("member")
		
				## Either group is empty or has 1500+ members
				if ($members.count -eq 0) {                       
		
					$retrievedAllMembers = $false           
					$rangeBottom = 0
					$rangeTop = 0
		
					while (! $retrievedAllMembers) {
						$rangeTop = $rangeBottom + 1499               
		
						##this is how it would show up in AD
						$memberRange = "member;range=$rangeBottom-$rangeTop"  
		
						$searcher.PropertiesToLoad.Clear()
						[void]$searcher.PropertiesToLoad.Add("$memberRange")
						$rangeBottom += 1500
		
						try {
							## should cause and exception if the $memberRange is not valid
							$result = $searcher.FindOne() 
							$rangedProperty = $result.Properties.PropertyNames -like "member;range=*"
							$members += $result.Properties.item($rangedProperty)          
						   
							#  check for empty group
							if ($members.count -eq 0) { $retrievedAllMembers = $true }
						}
		
						catch {
							$retrievedAllMembers = $true   ## we received all members
						}
					}
				}

				# display all members of the group
				if ($members.Count -eq 0) {
					Write-Warning "The group '$($group.Properties.name[0])' does not contain any members"
				}
				foreach ($member in $members) {
					$memberDetails = [ADSI] "LDAP://$member" 

					[PSCustomObject]@{
						PSTypeName    = "ADTools.GetADGroupMembers.Result"
						Group          = $group.Properties.name[0]
						samAccountName = $memberDetails.samAccountName.ToString()
						DisplayName    = $memberDetails.displayName.ToString()
						ObjectClass    = $memberDetails.objectClass[-1]
						DN             = $member
					}	
				}
			}
			$searcher.Dispose()			
		}
	}
}



