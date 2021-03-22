#----------------------------------------------------
# Return all members of a group. Works around ADSI issue of only 1500 members returned by 'members' property
# Sourced from https://www.adilhindistan.com/2013/01/getting-members-of-large-groups-via.html
function Get-GroupMembers {

    param (
        [string] $group
    )

    if (-not ($group)) { 
        return $false 
    }

    $searcher = new-object System.DirectoryServices.DirectorySearcher   
    $filter = "(&(objectClass=group)(cn=${group}))"
    $searcher.PageSize = 1000
    $searcher.Filter = $filter
    $result = $searcher.FindOne()

    if ($result) {
		write-host "group membership of $($result.Properties.name)" -ForegroundColor Green
        $members = $result.properties.item("member")

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

        $searcher.Dispose()
        return $members
    }
    return $false   
}


#----------------------------------------------------
# returns a string describing the AD group type
function GetGroupType {
    param (
        [string] $groupTypeID
    )

    if (-not ($groupTypeID)) { 
        return $false 
    }

    Switch ($groupTypeID) {
        2 {
            $groupType = "Global Distribution Group"
            break
        }
        4 {
            $groupType = "Domain Local Distribution Group"
            break
        }
        8 {
            $groupType = "Universal Distribution Group"
            break
        }
        -2147483646 {
            $groupType = "Global Security Group"
            break
        }
        -2147483644 {
            $groupType = "Domain Local Security Group"
            break
        }
        -2147483640 {
            $groupType = "Universal Security Group"
            break
        }
        -2147483643 {
            $groupType = "BuiltIn Group"
            break
        }
    }
    return $groupType
}


#----------------------------------------------------
# Convert the AD Date/Time field into a Date object
function ConvertADDateTime ($dateTimeValue) {
    if (($dateTimeValue -gt [DateTime]::MaxValue.Ticks) -or ($dateTimeValue -eq 0)) {
        return "Never"
    }
    else {
        return [datetime]::FromFileTime($dateTimeValue)
    }
}

#----------------------------------------------------
# Return the hostname portion of a fully qualified domain name
function GetShortHostname ($FQDN) {
	return ($FQDN -split "\.")[0]
}


