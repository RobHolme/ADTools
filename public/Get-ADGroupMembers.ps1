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
.PARAMETER Identity 
The name AD user group 
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
        # confirm the powershell version and platform requirements are met if using powershell core
        if ($IsCoreCLR) {
            if (($PSVersionTable.PSVersion -lt 6.1) -or ($PSVersionTable.Platform -ne "Win32NT")) {
                Write-Warning "This function requires Powershell Core 6.1 or greater on Windows."
                $abort = $true
            }
        }
    }

    process {
        if (!$abort) {

            $members = Get-GroupMembers $Name

            if ($members -eq $false) {
                Write-Warning "No group matching '$Name' found"
            }
            elseif ($members.Count -eq 0) {
                Write-Warning "The group '$Name' does not contain any members"
            }
            else {
                foreach ($member in $members) {
                    $memberDetails = [ADSI] "LDAP://$member" 
                  
                    # display the properties or each group member                 
                    $Result = [ORDERED]@{
                        DisplayName    = $memberDetails.displayName.ToString()
                        SamAccountName = $memberDetails.samAccountName.ToString()
                        ObjectClass    = $memberDetails.objectClass[-1]
                        DN             = $member
                    }
                    $outputObject = New-Object -Property $Result -TypeName psobject
                    $outputObject.PSObject.TypeNames.Insert(0, "Powertools.GetADGroupMembers.Result")
                    write-output $outputObject 
                }
            }
        }
    }
}

