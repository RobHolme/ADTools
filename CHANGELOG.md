# Change Log
* 1.0.0 	- initial module version (moved out to a separate module from PowerTools module).
* 1.0.3 	- fixed LDAP filters to search for users, not users and contacts.
* 1.0.4 	- added -AllProperties switch.
* 1.0.5 	- added -Displayname search switch for Get-ADUserDetails.
* 1.1.0 	- added Get-ADUserLastLogon command.
* 1.1.1 	- added progress bar for Get-ADUserLastLogon - can be slow in large environments.
* 1.2.0 	- added Get-ADSites command.
* 1.2.1 	- added -SiteName parameter to only query DCs from a specific AD site.
* 1.2.2 	- changed all functions not to default to wildcard searches. User must now include the '*' in search parameters.
* 1.2.3 	- updated Get-AdObjectGroupmembership to return multiple matches
* 1.2.4 	- updated Get-AdGroupMembers to support matches for multiple groups (wildcard matches). Results grouped by Group.
* 1.2.5 	- removed account lockout status from Get-ADUserDetails as it's only populated for AD pre 2003.
    		- updated view to highlight disabled & expired account attributes in red if expired (Get-ADUserDetails)
* 1.2.6 	- Changed view of Get-ADObjectGroupMemebership to group results by user
* 1.2.7 	- Updated results use [PSCustomObject]. No functional changes.
* 1.2.8		- Added account lockout status to Get-ADUserDetails
* 1.3.0		- Added Get-ADUserLockoutStatus command to report on AD account lockouts
* 1.3.1		- Updated Get-ADUserLastLogon to report the site associated with each DC
* 1.3.2		- Updated Get-ADObjectGroupMembership to wriete warning of no objects found, or the object is not a member of any groups