
function Convert-ADTimestamp {
    <#
.NOTES
Function Name   : Convert-ADTimestamp
Author          : Rob Holme (rob@holme.com.au)
Version         : 1.0 (06/10/2016)
                : 1.1 (09/01/2019) - checked for 'never expires' timestamps
Requires        : PowerShell V2

.SYNOPSIS
Converts a integer timestamp (e.g. from LDIFDE or some AD CmdLets) to a date/time value.
.DESCRIPTION
Converts a integer timestamp (e.g. from LDIFDE or some AD CmdLets) to a date/time value.
.EXAMPLE
Convert-ADTimestamp -Value 131200456520442703
.PARAMETER Value
The timestamp to convert
#>

    Param(
        [Parameter(
            Position = 0,
            Mandatory = $True,
            ValueFromPipeline = $True
        )]
        [string] $Value)

    process {
        if ($Value -gt [DateTime]::MaxValue.Ticks) {
            write-warning "Time value exceeds max value. This is used identify a time value of never expires."
        }
        else {
            $convertedDateTime = [datetime]::FromFileTime($Value)
            write-output $convertedDateTime
        }
    }
}

