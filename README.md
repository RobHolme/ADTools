# ADTools
Query (read only) tools for Active Directory. Intended for use on workstations where rights to install AD RSAT Powershell is not provided. Only provides basic viewing of properties of AD user and group objects. **Use RSAT Powershell module in preference to this module if available.**

Most functions assume the user has rights to read relevant account properties. This may not be the case if 'Authenticated Users' has been removed from the 'Built-in\pre-Windows 2000 compatible access' security group. In this case you may need to use an account with greater rights.

- [Find-ADGroup](#find-adgroup)
- [Get-ADGroupMembers](#get-adgroupmembers)
- [Get-ADObjectGroupMembership](#get-adobjectgroupmembership)
- [Get-ADUserDetails](#get-aduserdetails)
- [Get-ADUserLastLogon](#get-aduserlastlogon)
- [Get-ADUserLockoutStatus](#get-aduserlockoutstatus)
- [Get-ADSites](#get-adsites)
- [Convert-ADTimestamp](#convert-adtimestamp)



## Find-ADGroup
### Description
Searches for all groups matching a name. Exact match unless a wildcard modifier '*' is included in the string.

### Syntax
```PowerShell
Find-ADGroup [-Name] <String> [<CommonParameters>]
```

### Parameter
__-Name \<string\>__: The name of the group

### Examples
```
Find-ADGroup -Name "VPN Users"
```

## Get-ADGroupMembers
### Description
Display the members of an active directory group

### Syntax
```PowerShell
Get-ADGroupMembers [-Name] <String> [<CommonParameters>]
```

### Parameter
__-Name \<string\>__: The name of the group

### Examples
```
Get-ADGroupMembers -Name "VPN Users"
```

## Get-ADObjectGroupMembership
### Description
Display the group membership for an AD object. Defaults to user objects, unless -ObjectType parameter used to query Computer, Contact, or Group objects. Exact match unless a wildcard modifier '*' is included in the string.

### Syntax
```PowerShell
Get-ADObjectGroupMembership [-Identity] <String> [[-ObjectType] <String>] [<CommonParameters>]
```

### Parameter
__-Identity \<string\>__: The user identity (samAccountName) to search for.

### Examples
```
Get-ADObjectGroupMembership -Identity Rob

Get-ADObjectGroupMembership -Identity Server1 -ObjectType Computer
```

## Get-ADUserDetails
### Description
Display the common properties for an AD user account. Exact match for each search parameter unless a wildcard modifier '*' is included in the string.

### Syntax
```PowerShell
Get-ADUserDetails [-Identity] <String> [-AllProperties] [<CommonParameters>]

Get-ADUserDetails [[-Surname] <String>] [[-Firstname] <String>] [-AllProperties] [<CommonParameters>]

Get-ADUserDetails [-Displayname] <String> [-AllProperties] [<CommonParameters>]

Get-ADUserDetails [-EmailAddress] <String> [-AllProperties] [<CommonParameters>]
```

### Parameter
__-Identity \<string\>__: The user identity (samAccountName) to search for.

__-Surname \<string\>__: The user surname to search for.

__-Firstname \<string\>__: The user firstname to search for.

__-Displayname \<string\>__: The user Displayname to search for.

__-EmailAddress \<string\>__: The user's primary email address to search for.

__-AllProperties__: Switch to include all AD user attributes.


### Examples
```
# Find user with Logon Id matching 'Rob' exactly.
Get-ADUserDetails -Identity rob

# Find all users with Logon Id matching 'Rob', display all AD properties
Get-ADUserDetails -Identity rob -AllProperties

# Find all users with surname of 'Holme' and firstname beginning with 'R'
Get-ADUserDetails -Surname Holme -Firstname R*

# Find all users with surname starting with 'Ho' 
Get-ADUserDetails -Surname Ho*

# Find all users with a displayname stating with "SQL Service"
Get-ADUserDetails -Displayname "SQL Service*"

# Find the user with a primary email address of 'test@company.com.au'
Get-ADUserDetails -EmailAddress test@company.com.au
```


## Get-ADUserLastLogon
### Description
Query all domain controllers and return the most recent logon date/time. Exact match on Identity parameter unless a wildcard modifier '*' is included in the string.

### Syntax
```PowerShell
Get-ADUserLastLogon [-Identity] <String> [-ShowAllDomainControllers] [-SiteName <String>] [-Timeout <Int32>] [<CommonParameters>]
```
### Parameters
__-Identity \<string\>__: The user identity (samAccountName) to search for.

__-ShowAllDomainControllers__: List the logon times reported by each Domain Controller for a user.

__-SiteName \<string\>__: Only query Domain Controllers from this nominated site only.

__-Timeout \<int\>__: Timeout in seconds if Domain Controller does not respond (between 1 and 20 seconds). Defaults to 3 seconds.

### Examples
```
# Get last logon time for user 'rob' for all domain controllers in the current domain
Get-ADUserLastLogon -Identity rob

# Get last logon time for user 'rob' for domain controllers in the default-first-site-name only
Get-ADUserLastLogon -Identity rob -SiteName default-first-site-name
```


## Get-ADSites
### Description
Return details of all sites in the current forest.

### Syntax
```PowerShell
Get-ADSites [-CurrentSite] [<CommonParameters>]
```

### Parameters
__-CurrentSite__: Switch to display the current site only.

### Examples
```
# get all sites in the current forest
Get-ADSites

# get the current site the workstation belongs to
Get-ADSites -CurrentSite
```

## Get-ADUserLockoutStatus
### Description
Query all domain controllers and return the lockout status for each account. Exact match on Identity parameter unless a wildcard modifier '*' is included in the string.

### Syntax
```PowerShell
Get-ADUserLockoutStatus [-Identity] <String> [-Timeout <Int32>] [<CommonParameters>]
```
### Parameters
__-Identity \<string\>__: The user identity (samAccountName) to search for.

__-Timeout \<int\>__: Timeout in seconds if Domain Controller does not respond (between 1 and 20 seconds). Defaults to 3 seconds.

### Examples
```
# Get last lockout status for user 'rob' for all domain controllers in the current domain
PS> Get-ADUserLockoutStatus -Identity rob

LogonID DisplayName LockoutStatus LockoutTime BadPwdCount LastBadPassword       DomainController Site
------- ----------- ------------- ----------- ----------- ---------------       ---------------- ----
Rob     Rob         Unlocked      N/A         0           12/01/2021 6:38:26 AM WS001DC          Default-First-Site-Name
Rob     Rob         Unlocked      N/A         0           8/01/2021 12:58:12 PM WS002DC          Default-First-Site-Name

```

## Convert-ADTimestamp
### Description 
Converts a integer timestamp (e.g. from LDIFDE or some AD CmdLets) to a date/time value.

### Syntax
```PowerShell
Convert-ADTimestamp [-Value] <String> [<CommonParameters>]
```

### Examples
``` 
PS> Convert-ADTimestamp -Value 132306069444066678

Monday, 6 April 2020 8:35:44 AM
```
