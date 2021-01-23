# ADTools
Query only tools for Active Directory. Intended for use on workstations were rights to install AD RSAT Powershell is not provided. **Use RSAT Powershell module in preference to this module if available.**

- Convert-ADTimestamp
- Find-ADGroup
- Get-ADGroupMembers
- Get-ADObjectGroupMembership
- Get-ADSites
- Get-ADUserDetails
- Get-ADUserLastLogon

## Convert-ADTimestamp
### Description 
Converts a integer timestamp (e.g. from LDIFDE or some AD CmdLets) to a date/time value.

### Syntax
```PowerShell
Convert-ADTimestamp [-Value] <String> [<CommonParameters>]
```

### Examples
``` Convert-ADTimestamp -Value 132306069444066678```

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
```Find-ADGroup -Name "VPN Users"```

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
```Get-ADGroupMembers -Name "VPN Users"```

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
```

### Parameter
__-Identity \<string\>__: The user identity (samAccountName) to search for.

__-Surname \<string\>__: The user surname to search for.

__-Firstname \<string\>__: The user firstname to search for.

__-Displayname \<string\>__: The user Displayname to search for.


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
```


## Get-ADUserLastLogon
### Description
Query all domain controllers and return the most recent logon date/time. Exact match on Identity parameter unless a wildcard modifier '*' is included in the string.

## Syntax
```PowerShell
Get-ADUserLastLogon [-Identity] <String> [-ShowAllDomainControllers] [-SiteName <String>] [<CommonParameters>]
```
## Parameters
__-Identity \<string\>__: The user identity (samAccountName) to search for.

__-ShowAllDomainControllers__: List the logon times reported by each Domain Controller for a user.

__-SiteName \<string\>__: Only query Domain Controllers from this nominated site only.

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

## Syntax
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

## Syntax
```PowerShell
Get-ADUserLockoutStatus [-Identity] <String> [<CommonParameters>]
```
## Parameters
__-Identity \<string\>__: The user identity (samAccountName) to search for.

### Examples
```
# Get last lockout status for user 'rob' for all domain controllers in the current domain
Get-ADUserLockoutStatus -Identity rob

LogonID DisplayName LockoutStatus LockoutTime BadPwdCount LastBadPassword       DomainController Site
------- ----------- ------------- ----------- ----------- ---------------       ---------------- ----
Rob     Rob         Unlocked      Never       0           12/01/2021 6:38:26 AM WS001DC          Default-First-Site-Name
Rob     Rob         Unlocked      Never       0           8/01/2021 12:58:12 PM WS002DC          Default-First-Site-Name

```

# Change Log
* 1.0.0 - initial module version forked from PowerTools module.
* 1.0.3 - fixed relevant LDAP filters to search for users, not users and contacts.
* 1.0.4 - added -AllProperties switch.
* 1.0.5 - added -Displayname search switch for Get-ADUserDetails.
* 1.1.0 - added Get-ADUserLastLogon command.
* 1.1.1 - added progress bar for Get-ADUserLastLogon - can be slow in large environments.
* 1.2.0 - added Get-ADSites command.
* 1.2.1 - added -SiteName parameter to only query DCs from a specific AD site.
* 1.2.2 - changed all functions not to default to wildcard searches. User must now include the '*' in search parameters.
* 1.2.3 - updated Get-AdObjectGroupmembership to return multiple matches
* 1.2.4 - updated Get-AdGroupMembers to support matches for multiple groups (wildcard matches). Results grouped by Group.
* 1.2.5 - removed account lockout status from Get-ADUserDetails as it's only populated for AD pre 2003.
		- updated view to highlight disabled & expired account attributes in red if expired (Get-ADUserDetails)
* 1.2.6 - Changed view of Get-ADObjectGroupMemebership to group results by user
* 1.2.7 - Updated results use [PSCustomObject]. No functional changes.
* 1.2.8 - Added account lockout status to Get-ADUserDetails
* 1.2.9 - Added Get-ADUserLockoutStatus to report on AD account lockouts