<#
    .DESCRIPTION
        Remediate Azure Policy "Configure Log Analytics extension on Azure Arc enabled Windows servers" with PowerShell 
        Based on https://adatum.no/azure/azure-policy/remediate-azure-policy-with-powershell

    .NOTES
        AUTHOR: Alejandro Sanchez Gomez
        LASTEDIT: Nov 22, 2021
#>

Param
(
  [Parameter (Mandatory= $false)]
  [String] $resourceGroup
)

"Please enable appropriate RBAC permissions to the system identity of this automation account. Otherwise, the runbook may fail..."

try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

# Definition name for policy Configure Log Analytics extension on Azure Arc enabled Windows/Linux servers
$policyDefinitionNames = @('69af7d4a-7b18-4044-93a9-2651498ef203','9d2b61b4-1d14-4a63-be30-d4498e7ad2cf')

# get all non-compliant policies that can be remediated
if($resourceGroup)
{
    # at resourceGroupLevel
    $nonCompliantPolicies = Get-AzPolicyState -ResourceGroupName $resourceGroup | Where-Object { $_.ComplianceState -eq "NonCompliant" -and $_.PolicyDefinitionName -in $policyDefinitionNames -and $_.PolicyDefinitionAction -eq "deployIfNotExists" }
}
{
    # at subscriptionLevel
    $nonCompliantPolicies = Get-AzPolicyState | Where-Object { $_.ComplianceState -eq "NonCompliant" -and $_.PolicyDefinitionName -in $policyDefinitionNames -and $_.PolicyDefinitionAction -eq "deployIfNotExists" }
}

# loop through and start individual tasks per policy 
foreach ($policy in $nonCompliantPolicies) {

    $remediationName = "rem." + $policy.PolicyDefinitionName
    
    # Policy assigned at RG level -- Remedation done at RG level
    if($policy.PolicyAssignmentId -like "*resourcegroups*"){
        $scope = $policy.PolicyAssignmentId.Split("/")[4]
        Start-AzPolicyRemediation -Name $remediationName -ResourceGroupName $scope -PolicyAssignmentId $policy.PolicyAssignmentId -ResourceDiscoveryMode ReEvaluateCompliance
    }
    # Policy assigned at MG level -- Remedation done at MG level
    elseif($policy.PolicyAssignmentId -like "*managementGroups*") {
        $scope = $policy.PolicyAssignmentId.Split("/")[4]
        Start-AzPolicyRemediation -Name $remediationName -ManagementGroupName $scope -PolicyAssignmentId $policy.PolicyAssignmentId -ResourceDiscoveryMode ReEvaluateCompliance
    
    }
    # Policy assigned at subscription level -- Remedation done at subscription level
    else {
        Start-AzPolicyRemediation -Name $remediationName -PolicyAssignmentId $policy.PolicyAssignmentId -ResourceDiscoveryMode ReEvaluateCompliance
    }
}