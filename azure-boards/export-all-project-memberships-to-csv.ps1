# Currently using the Identities API because this only works on both Azuer DevOps and Azure DevOps Server

$ErrorActionPreference = "Stop"

$orgOrCollection = "YOUR_ORG_OR_COLLECTION"
 $coll = "https://server/tfs/$orgOrCollection"
 $vssps = "https://server/tfs/$orgOrCollection"

$apiVersion = "7.1-preview.1"

$filepathprojectpermissions = "C:\temp\projectmemberships.csv"
$pat = Get-Content -Path ".\pat.txt"
$encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$pat"))
$header = @{Authorization = "Basic $encodedPat"}
$apiurl = "$coll/_apis"
$vsspsurl = "$vssps/_apis"

Class AgentPoolEntry {
    [int]$AgentPoolId
    [string]$AgentPoolName
    [int]$AgentId
    [string]$AgentName
    [bool]$AgentEnabled
    [string]$AgentStatus
    [string]$AgentVersion
    [string]$AgentHomeDirectory
    [string]$AgentUserDomain
    [string]$AgentUserName
    [string]$AgentComputerName
    [string]$AgentOS
    [bool]$AgentHasUserCapabilities
}

Class UserCapability {
    [int]$AgentId
    [string]$UserCapabilityKey
    [string]$UserCapabilityValue
}

function Get-JsonOutput($uri, [bool]$usevalueproperty = $true) {
    $output = (invoke-webrequest -Uri $uri -Method GET -ContentType "application/json" -Headers $header) | ConvertFrom-Json
    if ($usevalueproperty)
    {
        return $output.value
    }
    else 
    {
        return $output
    }
}

function Get-Projects ($continuationToken=0) {
    return Get-JsonOutput -uri "$apiurl/projects?continuationToken=$continuationToken"
}
function Get-Identities ($filterValue, $queryMembership) {
    return Get-JsonOutput -uri "$vsspsurl/identities?searchFilter=General&filterValue=$($filterValue)&queryMembership=$($queryMembership)&api-version=$($apiVersion)"
}
function Get-IdentitiesById ($identityIds, $queryMembership) {
    return Get-JsonOutput -uri "$vsspsurl/identities?identityIds=$($identityIds)&queryMembership=$($queryMembership)&api-version=$($apiVersion)"
}
function Get-Memberships ($subjectDescriptor, $direction="down") {
    return Get-JsonOutput -uri "$vsspsurl/graph/Memberships/$($subjectDescriptor)?direction=$direction"
}
function Get-Users ($subjectDescriptor) {
    return Get-JsonOutput -uri "$vsspsurl/graph/users?scopeDescriptor=$subjectDescriptor"
}

function Get-MemberIdentities ($Identity, $ResultList, $Dept) {
    $indent = "".PadLeft($Dept*2," ")
    Write-Host "$($indent)Processing identity '$($Identity.providerDisplayName)'"
    $ResultList.add
    $groupMemberIds = $Identity.memberIds -join ","
    if ($groupMemberIds.Length -gt 0 ) {
        $groupMemberIdentities = Get-IdentitiesById -identityIds $groupMemberIds -queryMembership "direct"
        foreach ($groupMember in $groupMemberIdentities)
        {
            $newDepth = $Dept + 1
            Get-MemberIdentities -identity $groupMember -ResultList $ResultList -Dept $newDepth
        }
    }

}

#$projects = Get-Projects

$ProjectValidUsers = Get-Identities -filterValue "Project%20Valid%20Users" -queryMembership "direct"

$resultList = New-Object System.Collections.ArrayList
$resultList.a
foreach ($pvuGroup in $ProjectValidUsers)
{
    Get-MemberIdentities -Identity $pvuGroup -ResultList $resultList -Dept 0
}

Write-Host "Writing CSV file"
$resultList | Export-Csv -Path $filepathprojectpermissions -UseCulture
Write-Host "Done"
