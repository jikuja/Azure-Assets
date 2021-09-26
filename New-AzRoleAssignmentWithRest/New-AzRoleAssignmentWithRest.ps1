[CmdletBinding(DefaultParameterSetName = "Scope")]
param (
    [Parameter(Mandatory = $true, ParameterSetName = "Scope")]
    [string]
    $Scope,

    [Parameter(Mandatory = $true, ParameterSetName = "ManagementGroupScope")]
    [string]
    $ManagementGroupId,

    [Parameter(Mandatory = $true, ParameterSetName = "SubscriptionScope")]
    [Parameter(Mandatory = $true, ParameterSetName = "ResourcegroupScope")]
    [Parameter(Mandatory = $true, ParameterSetName = "ResourceScope")]
    [string]
    $SubscriptionId,

    [Parameter(Mandatory = $true, ParameterSetName = "ResourcegroupScope")]
    [Parameter(Mandatory = $true, ParameterSetName = "ResourceScope")]
    [string]
    $ResourcegroupName,

    [Parameter(Mandatory = $true, ParameterSetName = "ResourceScope")]
    [string]
    $ResourceName,

    [Parameter(Mandatory = $true, ParameterSetName = "ResourceScope")]
    [string]
    $ResourceType,

    [Parameter(Mandatory = $false, ParameterSetName = "ResourceScope")]
    [string]
    $ParentResource
    ,

    [Parameter(Mandatory = $true)]
    [string]
    $ObjectId,

    [Parameter(Mandatory = $true)]
    [string]
    $RoleDefinitionId,

    [Parameter(Mandatory = $false)]
    [string]
    $Description,

    [Parameter(Mandatory = $false, HelpMessage = "User, Group, ServicePrincipal, FroreignGroup or Device")]
    [string]
    $PrincipalType,

    [Parameter(Mandatory = $false)]
    [switch]
    $WhatIf,

    [Parameter(Mandatory = $false)]
    [string]
    $ApiVersion = "2021-04-01-preview",

    [Parameter(Mandatory = $false)]
    [string]
    $DelegatedManagedIdentityResourceId
)

function ConvertResponseToString {
    [CmdletBinding()]
    param (
        [Parameter()]
        [Microsoft.Azure.Commands.Profile.Models.PSHttpResponse]
        $response
    ) 

    @"
============================ HTTP RESPONSE ============================
Status code: $($response.StatusCode)
Headers: Not available
Body: $($response.Content)
"@
    return
}

function ConvertParamsToString {
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Collections.Hashtable]
        $params
    )
    @"
============================ HTTP REQUEST ============================
Params: $($params | ConvertTo-Json)
"@
    return
}

# should be generated from ids/names
$roleAssignmentId = New-Guid

$calculatedScope = switch ($PSCmdlet.ParameterSetName) {
    "Scope" { $Scope }
    "ManagementGroupScope" { "/providers/Microsoft.Management/managementGroups/${ManagementGroupId}" }
    "SubscriptionScope" { "/subscriptions/${SubscriptionId}" }
    "ResourcegroupScope" { "/subscriptions/${SubscriptionId}/resourceGroups/${ResourcegroupName}" }
    "ResourceScope" { if ($ParentResource) {
        "/subscriptions/${SubscriptionId}/resourceGroups/${ResourcegroupName}/providers/${ResourceType}/${ParentResource}/${ResourceName}"
     } else {
        "/subscriptions/${SubscriptionId}/resourceGroups/${ResourcegroupName}/providers/${ResourceType}/${ResourceName}"
     } }
    Default { throw "Invalid ParamaterSet" }
}

$properties = @{
    roleDefinitionId = "${calculatedScope}/providers/Microsoft.Authorization/roleDefinitions/${RoleDefinitionId}"
    principalId = $ObjectId
}

if ($Description) {
    $properties.Add("description", $Description)
}

if ($PrincipalType) {
    $properties.Add("principalType", $PrincipalType)
}

if ($DelegatedManagedIdentityResourceId) {
    $properties.Add("delegatedManagedIdentityResourceId", $DelegatedManagedIdentityResourceId)
}

$Url = "${calculatedScope}/providers/Microsoft.Authorization/roleAssignments/${roleAssignmentId}?api-version=${ApiVersion}"

$payload = @{
    properties = $properties
}

$params = @{
    Path = $Url
    Method = 'PUT'
    Payload = $payload | ConvertTo-Json
}

Write-Verbose "Invoking: PUT ${Url} with payload: "
Write-Verbose ($params | ConvertTo-Json)

if (!$WhatIf) {
    $result = Invoke-AzRestMethod @params
    Write-Verbose "Return value: $result"  
    $body = $result.Content | ConvertFrom-Json 
    switch ($result.StatusCode) {
        200 {
            Write-Host "Success"
        }
        201 {
            Write-Host "Success"
        }
        409 { if ($body.error.code -eq "RoleAssignmentExists") {
                Write-Host "Success: assignment already exists"
            } else {
                Write-Error @"
Request failed:
$(ConvertParamsToString($params))
$(ConvertResponseToString($result))
"@
            }
        }
        Default { 
            Write-Error @"
Request failed:
$(ConvertParamsToString($params))
$(ConvertResponseToString($result))
"@
        }
    }
}

# TODO:
# * add support for JSON inputfile
# * add support for conditions