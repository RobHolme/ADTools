# ADTools
Query only tools for Active Directory. Intended for use on workstations were rights to install AD RSAT Powershell is not provided. Use RSAT Powershell module in preference to this module if available.

- Convert-ADTimestamp
- Find-ADGroup
- Get-ADGroupMembers
- Get-ADObjectGroupMembership
- Get-ADUserDetails

## Convert-ADTimestamp
### Description 
Converts a integer timestamp (e.g. from LDIFDE or some AD CmdLets) to a date/time value.
### Syntax
```Convert-ADTimestamp [-Value] <String> [<CommonParameters>]```

### Examples
``` Convert-ADTimestamp -Value 132306069444066678```

## Find-ADGroup
### Description
Searches for all groups matching a name. Wildcard match on names starting with the value provided in the Name parameter.

### Syntax
```Find-ADGroup [-Name] <String> [<CommonParameters>]```

### Examples
```Find-ADGroup -Name "VPN Users"```

## Get-ADGroupMembers
### Description
Display the members of an active directory group
### Syntax
```Get-ADGroupMembers [-Name] <String> [<CommonParameters>]```
### Examples
```Get-ADGroupMembers -Name "VPN Users"```

## Get-ADObjectGroupMembership
### Description
Display the group membership for an AD object. Defaults to user objects, unless -ObjectType parameter used to query Computer, Contact, or Group objects.
### Syntax
```Get-ADObjectGroupMembership [-Identity] <String> [[-ObjectType] <String>] [<CommonParameters>]```
### Examples
```
Get-ADObjectGroupMembership -Identity Rob

Get-ADObjectGroupMembership -Identity Server1 -ObjectType Computer

```
## Get-ADUserDetails
### Description
Display the common properties for an AD user account. Searching -Identity is excact match, while name matches will return all results starting with the names provided. 
### Syntax
```
Get-ADUserDetails [-Identity] <String> [<CommonParameters>]

Get-ADUserDetails [[-Surname] <String>] [[-Firstname] <String>] [<CommonParameters>]
```
### Examples
```
# Find all users with Logon Id matching 'Rob'
Get-ADUserDetails -Identity rob

# Find all users with surname of 'Holme' and firstname beginning with 'R'
Get-ADUserDetails -Surname Holme -Firstname R

# Find all users with surname starting with 'Ho' 
Get-ADUserDetails -Surname Ho
```

# Change Log
## 1.0.0 - initial module version forked from PowerTools module
## 1.0.3 - fixed relevant LDAP filters to search for users, not users and contacts.
## 1.0.4 - added -AllProperties switch
