# ADTools
Query only tools for Active Directory. Intended for use on workstations were rights to install AD RSAT Powershell is not provided. **Use RSAT Powershell module in preference to this module if available.**

- Convert-ADTimestamp
- Find-ADGroup
- Get-ADGroupMembers
- Get-ADObjectGroupMembership
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
Searches for all groups matching a name. Wildcard match on names starting with the value provided in the Name parameter.

### Syntax
```PowerShell
Find-ADGroup [-Name] <String> [<CommonParameters>]
```

### Examples
```Find-ADGroup -Name "VPN Users"```

## Get-ADGroupMembers
### Description
Display the members of an active directory group
### Syntax
```PowerShell
Get-ADGroupMembers [-Name] <String> [<CommonParameters>]
```
### Examples
```Get-ADGroupMembers -Name "VPN Users"```

## Get-ADObjectGroupMembership
### Description
Display the group membership for an AD object. Defaults to user objects, unless -ObjectType parameter used to query Computer, Contact, or Group objects.
### Syntax
```PowerShell
Get-ADObjectGroupMembership [-Identity] <String> [[-ObjectType] <String>] [<CommonParameters>]
```
### Examples
```
Get-ADObjectGroupMembership -Identity Rob

Get-ADObjectGroupMembership -Identity Server1 -ObjectType Computer
```
## Get-ADUserDetails
### Description
Display the common properties for an AD user account. All search criteria will return all results starting with the name(s) or identity provided. 
### Syntax
```PowerShell
Get-ADUserDetails [-Identity] <String> [-AllProperties] [<CommonParameters>]

Get-ADUserDetails [[-Surname] <String>] [[-Firstname] <String>] [-AllProperties] [<CommonParameters>]

Get-ADUserDetails [-Displayname] <String> [-AllProperties] [<CommonParameters>]
```
### Examples
```
# Find all users with Logon Id matching 'Rob'
Get-ADUserDetails -Identity rob

# Find all users with Logon Id matching 'Rob', display all AD properties
Get-ADUserDetails -Identity rob -AllProperties

# Find all users with surname of 'Holme' and firstname beginning with 'R'
Get-ADUserDetails -Surname Holme -Firstname R

# Find all users with surname starting with 'Ho' 
Get-ADUserDetails -Surname Ho

# Find all users with a displayname stating with "SQL Service"
Get-ADUserDetails -Displayname "SQL Service"
```


## Get-ADUserLastLogon
### Description
Query all domain controllers and return the most recent logon date/time.
## Syntax
```PowerShell
Get-ADUserLastLogon [-Identity] <String> [-ShowAllDomainControllers] [<CommonParameters>]
```
### Examples
Get-ADUserLastLogon -Identity rob

# Change Log
* 1.0.0 - initial module version forked from PowerTools module.
* 1.0.3 - fixed relevant LDAP filters to search for users, not users and contacts.
* 1.0.4 - added -AllProperties switch.
* 1.0.5 - added -Displayname search switch for Get-ADUserDetails.
* 1.1.0 - added Get-ADUserLastLogon command.
* 1.1.1 - added progress bar for Get-ADUserLastLogon - can be slow in large environments.
* 1.2.0 - added Get-ADSites command.