# Deployment Variables to choose what to deploy
$deployMonitorLAW = $true
$deployMonitorLAWDataSources = $true
$deployAutomationAccount = $true
$deployActionGroup = $true
$deployAlerts = $true
$deployWorkbooks = $true
$deployDashboard = $true
$deployAzurePolicies = $true
$deployDefenderForCloud = $true

# Global variables
$parametersFilePath = ".\Parameters.csv"
$parametersFileInput = $(Import-Csv $parametersFilePath)
$subscriptionName = $parametersFileInput.Subscription
$resourceGroup = $parametersFileInput.ResourceGroup
$namingPrefix = $parametersFileInput.NamingPrefix
$location = $parametersFileInput.Location
$MonitorWSName = $namingPrefix + "-la-monitor"
$SecurityWSName = $namingPrefix + "-la-security"
$ActionGroupName = $namingPrefix + "-ag-arc"
$ActionGroupShortName = $namingPrefix + "-agarc"
$AutomationAccountName = $namingPrefix + "-aa-arcservers"

# Option to interrupt the deployment  
Write-Host -ForegroundColor Green "STARTING THE DEPLOYMENT"
Write-Host -ForegroundColor Red "NOTE: Press CTRL+C within 10 seconds to cancel the deployment"
Start-Sleep -Seconds 10 

# Login to Azure
if ($(Get-AzContext).Name -eq "Default")
{
    Login-AzAccount  
}

# Switch Context to designated subscription if needed
if((Get-AzContext).Subscription.Name -ne $subscriptionName)
{
    Select-AzSubscription -SubscriptionName $subscriptionName | Out-Null
}

# Create the ResourceGroup if needed
Get-AzResourceGroup -Name $resourceGroup -ErrorVariable notPresent -ErrorAction SilentlyContinue | Out-Null
if ($notPresent)
{
    Write-Host "Creating resource group $resourceGroup"
    New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null
}

### Deploy the Monitor Log Analytics workspace
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying the Monitor Log Analytics Workspace"
if($deployMonitorLAW -eq $true)
{
    $deploymentName = "deploy_monitor_loganalytics_workspace"
    $templateFile = ".\MonitorLogAnalyticsWorkspace\deploy.json"
        
    # Deploy the workspace
    Write-Host "Deploying log analytics workspace $MonitorWSName"
    New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
    -workspaceName $MonitorWSName -location $location | Out-Null
    
}
else {
    Write-Host "Skipped"
}

### Enable LA Monitor Data Sources: Events, Performance Counters, etc
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying Data Sources in the Monitor the Log Analytics Workspace"
if($deployMonitorLAWDataSources -eq $true)
{
    $deploymentName = "deploy_data_sources"
    $templateFile = ".\MonitorLogAnalyticsWorkspace\DataSources\deploy.json"

    # Deploy the data sources
    Write-Host "Deploying data sources for $MonitorWSName"
    New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
    -workspaceName $MonitorWSName | Out-Null
}
else {
    Write-Host "Skipped"
}

### Automation account related resources
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying the Automation Account and related resources"
if($deployAutomationAccount -eq $true)
{
    $deploymentName = "deploy_automation_account"
    $templateFile = ".\AutomationAccount\deploy.json"
    $managedIdentityScope = $parametersFileInput.Scope

    # Deploy and link the automation account
    Write-Host "Deploying and linking automation account to $MonitorWSName"
    Write-Host "Deploying Update Management, Change Tracking and Inventory in the automation account $automationAccountName"
    New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
        -workspaceName $MonitorWSName -automationAccountName $automationAccountName -location $location | Out-Null

    # Create and publish the runbook
    $runbookName = "AutoRemediatePolicyLAAgentAzureArcServers"
    $runbookType = "PowerShell"
    $runbookCodePath = ".\AutomationAccount\Runbook\AutoRemediatePolicyLAAgentAzureArcServers.ps1"
    Write-Host "Importing the required runbooks"
    Import-AzAutomationRunbook -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroup  -Name $runbookName `    -Type $runbookType -Path $runbookCodePath | Out-null 
           
    Write-Host "Publishing the required runbooks"
    Publish-AzAutomationRunbook -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroup -Name $runbookName | Out-null

    # Create and link the schedule
    Write-Host "Creating the daily schedule and linking it to the runbook"
    $StartTime = Get-Date "23:00:00"
    $EndTime = $StartTime.AddYears(99)
    $scheduleName = "dailyschedule11pm"
    $TimeZone = ([System.TimeZoneInfo]::Local).Id
    New-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $scheduleName -StartTime $StartTime -ExpiryTime `
    $EndTime -DayInterval 1 -ResourceGroupName $resourceGroup -TimeZone $TimeZone | Out-null
    # Policy remedation will happen at subscription or resource group level, depending on the Scope parameter
    if($managedIdentityScope -eq "subscription")
    {
        Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
        -Name $runbookName -ScheduleName $scheduleName -ResourceGroupName $resourceGroup | Out-null
    }
    elseif($managedIdentityScope -eq "resourcegroup") {
        Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccountName `
        -Name $runbookName -ScheduleName $scheduleName -ResourceGroupName $resourceGroup `
        -Parameters @{"resourceGroup"=$resourceGroup} | Out-null
    }    

    # Get automation account managed identity and assign permissions to remediate policies at subscription/resource group level
    $principalId = (Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccountName).Identity.PrincipalId
    if($managedIdentityScope -eq "subscription")
    {
        New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Resource Policy Contributor" | Out-null
    }
    elseif($managedIdentityScope -eq "resourcegroup") {
        New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Resource Policy Contributor" `
        -ResourceGroupName $resourceGroup | Out-null
    }
}
else {
    Write-Host "Skipped"
}

### Create Azure Monitor action group with an email address
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying Azure Monitor Action Group"
if($deployActionGroup -eq $true)
{
    $deploymentName = "deploy_action_group"
    $templateFile = ".\ActionGroup\deploy.json"
    $emailAddress = $parametersFileInput.Email
        
    # Deploy the data sources
    Write-Host "Deploying Azure Monitor Action Group"
    New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
    -actionGroupName $actionGroupName -actionGroupShortName $actionGroupShortName -emailAddress $emailAddress | Out-Null
}
else {
    Write-Host "Skipped"
}

### Set up the alert baseline
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying Azure Monitor alerts"
if($deployAlerts -eq $true)
{         
    $templateBasePath = ".\Alerts"

    # Get the alerts ARM template files
    $alertCollection = $(ls -Path $templateBasePath | Where-Object {$_.name -like "*.json"})
        
    # Deploy all the alerts
    foreach ($alert in $alertCollection)
    {
        $alertName = $($alert.Name).Split(".")[0]
        $templateFile = "$templateBasePath\$($alert.Name)"
        $deploymentName = $("deploy_alert_$alertName").ToLower()

        # Deploy this alert
        Write-Host "Deploying alert: $alertName"
        New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
        -workspaceName $MonitorWSName -location $location -actionGroupName $actionGroupName | Out-Null
    }
}
else {
    Write-Host "Skipped"
}

### Deploy Azure Workbooks
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying Azure workbooks"
if($deployWorkbooks -eq $true)
{         
    $templateBasePath = ".\Workbooks"

    # Get the workbooks ARM template files
    $workbookCollection = $(ls -Path $templateBasePath | Where-Object {$_.name -like "*.json"})
        
    # Deploy all workbooks
    foreach ($workbook in $workbookCollection)
    {
        $workbookName = $($workbook.Name).Split(".")[0]
        $templateFile = "$templateBasePath\$($workbook.Name)"
        $deploymentName = $("Deploy_Workbook_$workbookName").ToLower()

        # Deploy this workbook
        Write-Host "Deploying workbook $workbookName"
        New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
        -workspaceName $MonitorWSName | Out-Null
            
    }
}
else {
    Write-Host "Skipped"
}

### Deploy the Azure dashboard
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying the Azure Dashboard"
if($deployDashboard -eq $true)
{
    $deploymentName = "deploy_azure_dashboard"
    $templateFile = ".\Dashboard\deploy.json"

    # Deploy the Azure Dashboard
    Write-Host "Deploying the Azure Dashboard"
    New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
    -workspaceName $MonitorWSName -location $location | Out-Null    
}
else {
    Write-Host "Skipped"
}

### Assign Azure Policies
Write-Host ""
Write-Host -ForegroundColor Cyan "Assigning required Azure Policies"
if($deployAzurePolicies -eq $true)
{        
    $templateBasePath = ".\Policies"
    $policiesScope = $parametersFileInput.Scope
    # Parameter to make unique Microsoft.Authorization/roleAssignments name at tenant level
    $resourceGroupID = (Get-AzResourceGroup -Name $resourceGroup).ResourceId

    # Get the AzurePolicies ARM template files
    $azurePoliciesCollection = $(ls -Path $templateBasePath | Where-Object {$_.name -like "*.json"})
        
    # Assign the policies
    foreach ($azurePolicyItem in $azurePoliciesCollection)
    {
        $azurePolicyName = $($azurePolicyItem.Name).Split(".")[0]
        $templateFile = "$templateBasePath\$($azurePolicyItem.Name)"
        $deploymentName = "assign_policy_$($azurePolicyName)".Replace(' ','')
        $deploymentName = $deploymentName.substring(0, [System.Math]::Min(63, $deploymentName.Length))

        # Assign the policy at resource group/subscription scope
        Write-Host "Assigning Azure Policy: $azurePolicyName"
        if($policiesScope -eq "subscription")
        {
            New-AzDeployment -Name $deploymentName -location $location -TemplateFile $templateFile `
            -workspaceName $MonitorWSName -policyAssignmentName $azurePolicyName -resourceGroupID `
            $resourceGroupID | Out-Null
        }
        elseif($policiesScope -eq "resourcegroup") {
            New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup `
            -TemplateFile $templateFile -workspaceName $MonitorWSName -location $location `
            -policyAssignmentName $azurePolicyName -resourceGroupID $resourceGroupID | Out-Null
        }
    }
}
else {
    Write-Host "Skipped"
}

### Deploy Microsoft Defender for Cloud
Write-Host ""
Write-Host -ForegroundColor Cyan "Deploying Microsoft Defender for Cloud"
if($deployDefenderForCloud -eq $true)
{
    $templateFile = ".\DefenderForCloud\deploy.json"
    $templateFileAtSubscription = ".\DefenderForCloud\deployatsubscription.json"
    $deploymentName = "deploy_defenderforcloud_resources"
    $deploymentNameAtSubscription = "deploy_defenderforcloud_subscriptionsettings"
    $emailAddress = $parametersFileInput.Email
    $securityCollectionTier = $parametersFileInput.securityCollectionTier
       
    # Deploy Defender for Cloud
    Write-Host "Deploying Microsoft Defender for Cloud resources"
    New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroup -TemplateFile $templateFile `
    -workspaceName $SecurityWSName -location $location -securityCollectionTier $securityCollectionTier | Out-Null

    # Deployment at subscription level: defender for servers and defender notification settings
    Write-Host "Deploying Microsoft Defender for Cloud settings at subscription level"
    New-AzDeployment -Name $deploymentNameAtSubscription -Location $location -TemplateFile $templateFileAtSubscription `
    -emails $emailAddress | Out-Null    
}
else {
    Write-Host "Skipped"
}
