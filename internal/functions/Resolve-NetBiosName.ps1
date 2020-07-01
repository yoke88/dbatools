function Resolve-NetBiosName {
    <#
.SYNOPSIS
Internal function. Takes a best guess at the NetBIOS name of a server.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$SqlInstance,
        [PSCredential]$SqlCredential
    )
    $server = Connect-SqlInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
    if($server.ComputerName){
        return $server.ComputerName
    }elseif($server.ComputerNamePhysicalNetBIOS){
        return $server.ComputerNamePhysicalNetBIOS
    }else{
        return $server.name
    }
}
