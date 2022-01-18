# Azure Arc Servers - Minimum Valuable Product (MVP)
## Content
- [Overview](https://github.com/alsanch/azurearcmvp#overview)
- [What resources are deployed?](https://github.com/alsanch/azurearcmvp#what-resources-are-deployed)
- [Requirements](https://github.com/alsanch/azurearcmvp#requirements)
- [Deployment steps](https://github.com/alsanch/azurearcmvp#deployment-steps)
- [Limitations](https://github.com/alsanch/azurearcmvp#limitations)
- [Screenshots](https://github.com/alsanch/azurearcmvp#screenshots)
- [References](https://github.com/alsanch/azurearcmvp#references)

## Overview
Azure Arc enables you to manage your entire environment, with a single pane of glass, by projecting your existing non-Azure, on-premises, or other-cloud resources into Azure Resource Manager. The first step is to onboard your on-premises servers into Azure Arc. Once your on-premises servers are onboarded, you can benefit from native Azure services like Azure Policy, Azure Monitor, and Azure Automation. This project helps you on deploying a Minimum Valuable Product (MVP) of these Azure Services. 

**Note:** the Azure Services deployed in this framework could also be used for Azure VMs as long as they are connected to the Log Analytics Workspace for Azure Monitor. 

## What resources are deployed?
- **Log Analytics Workspace for Azure Monitor**
- **Data Sources in the Log Analytics Workspace for Azure Monitor**
    - **Windows Events:** System, Application
    - **Windows Performance Counters:** LogicalDisk(*)\% Processor Time; LogicalDisk(*)\% Processor Time; LogicalDisk(*)\Avg. Disk sec/Write; LogicalDisk(*)\Current Disk Queue Length; LogicalDisk(*)\Current Disk Queue Length; LogicalDisk(*)\Disk Transfers/sec; LogicalDisk(*)\Disk Writes/sec; LogicalDisk(*)\Free Megabytes; Memory(*)\% Committed Bytes In Use; Memory(*)\Available MBytes; Network Adapter(*)\Bytes Received/sec; Network Adapter(*)\Bytes Sent/sec; Network Adapter(*)\Bytes Sent/sec; Process(*)\% Processor Time; Process(*)\% Processor Time; System(*)\Processor Queue Length
    - **Linux Performance Counters:** Logical Disk(*)\% Used Inodes; Logical Disk(*)\% Used Space; Logical Disk(*)\Disk Reads/sec; Logical Disk(*)\Disk Transfers/sec; Logical Disk(*)\Disk Transfers/sec; Logical Disk(*)\Free Megabytes; Memory(*)\% Used Memory; Memory(*)\% Used Swap Space; Memory(*)\Available MBytes Memory; Network(*)\Total Bytes Received; Network(*)\Total Bytes Transmitted; Processor(*)\%Privileged Time; Processor(*)\% Processor Time
    - **Syslog:** daemon; kern
- **VM insights in the Log Analytics Workspace for Azure Monitor**
- **Automation Account, links it to the Log Analytics Workspace for Azure Monitor, and includes:**
    - Change Tracking with "Enable on all available and future machines" enabled
    - Inventory with "Enable on all available and future machines" enabled
    - Update Management with "Enable on all available and future machines" enabled
    - Runbook called AutoRemediatePolicyLAAgentAzureArcServers.ps1, that triggers a remediation task for the policies "Configure Log Analytics extension on Azure Arc enabled Windows/Linux servers" and "Configure Dependency agent on Azure Arc enabled Windows/Linux servers" when there are pending resources to be remediated
      - Schedule to trigger the runbook once per day at 23:00:00 local time
      - Managed Identity with Resource Policy Contributor permissions at subscription/resource group level to trigger the remediation task
- **Azure Monitor action group with an email action**
- **Azure Monitor alerts based on log analytics workspace metrics:** processorTimePercent; commitedBytesInUsePercent; logicalDiskFreeSpacePercent
- **Azure Workbooks:** AlertsConsole; OSPerformanceAndCapacity; WindowsEvents; WindowsUpdates
- **Azure Dashboard that provides a monitoring overview for your Azure Arc Servers**
- **Azure Policies, with auto-remediation enabled and a system managed identity assigned:**
    - Configure Log Analytics extension on Azure Arc enabled Windows servers
    - Configure Log Analytics extension on Azure Arc enabled Linux servers
    - Configure Dependency agent on Azure Arc enabled Windows servers
    - Configure Dependency agent on Azure Arc enabled Linux servers
    - Configure Arc-enabled machines running SQL Server to have SQL Server extension installed
- **Required settings for Microsoft Defender for Cloud & Azure Arc Servers**
    - Deploys a Log Analyics Workspace for Security data
    - Enables the Security insights solution in the Log Analyics Workspace for Security data
    - Enables the collection of Security Events in the Log Analytics Workspace for Security data
    - Enables Microsoft Defender for Cloud for Servers at subscription level
    - Enables the notification settings at subscription level

**Note**: for **Microsoft Sentinel** deployment, please, refer to the project **Azure Sentinel All In One** (https://github.com/Azure/Azure-Sentinel/tree/master/Tools/Sentinel-All-In-One). You could deploy it on the previous Log Analytics Workspace for Security Data.

## Requirements
- **Tested in Powershell 5.1**
- **Azure Permissions:** Owner
    - Role required to assign the Resource Policy Contributor role to the Automation Account managed identity
    - Required at subscription level if Microsoft Defender for Cloud is deployed. Otherwise, at resource group level
- **Azure AD Permissions:** User

## Deployment steps
1. **Provide the required parameters in the Parameters.csv file:**
    - **Subscription:** name of your Azure Subscription
    - **ResourceGroup:** name of an existing or new resource group where the framework is deployed
    - **NamingPrefix:** lowercase prefix used in the name of the deployed resources
    - **Location:** Azure Region where the framework is deployed
    - **Email:** email account used in the Action Group for alerts and in the Microsoft Defender for Cloud notification settings
    - **Scope:** scope at which the Azure Policies and the Automation Account managed identity permissions are assigned. Allowed values: "subscription", "resourcegroup"
    - **SecurityCollectionTier:** SecurityEvent logging level. Allowed values: "All", "Recommended", "Minimal", "None"
2. Open PowerShell and **change your working directory** to the project directory
3. Run **Login-AzAccount**
4. Run **DeployAzureArcMVP.ps1**

**Note**: you can enable/disable what's deployed in this framework by using the deployment variables within DeployAzureArcMVP.ps1.

## Limitations
- The following two Azure Policies will not work if the servers already have a connection to a Log Analytics workspace (multi-homing is not supported in the MMA extension)
    - Configure Log Analytics extension on Azure Arc enabled Windows servers
    - Configure Log Analytics extension on Azure Arc enabled Linux servers
- The framework does not deploy a second log analytics connection from the Azure Arc Servers to the Security Log Analytis Workspace. (Work in Progress)

## Screenshots
![image](https://user-images.githubusercontent.com/96136892/149989258-91061aae-c1f1-4624-9f16-c6ac5d37b43d.png)

![image](https://user-images.githubusercontent.com/96136892/149988755-5070e7ff-e706-409c-b2a2-1934268c5217.png)

![image](https://user-images.githubusercontent.com/96136892/149988907-35e7a699-99d2-4fb4-b702-4e74dab1f227.png)

![image](https://user-images.githubusercontent.com/96136892/149988605-fba9f597-fb00-4908-be07-85851483b7f6.png)

![image](https://user-images.githubusercontent.com/96136892/149989430-6f7f318e-d7cc-4e12-ba95-1f74fbba157b.png)

![image](https://user-images.githubusercontent.com/96136892/149989168-526f84cb-fb3a-4c64-a3c3-87ef356f4545.png)

## References
- **Azure Arc-enabled servers:** https://docs.microsoft.com/en-us/azure/azure-arc/servers/
- **Azure Arc Jumpstart:** https://azurearcjumpstart.io/
- **Jumpstart ArcBox:** https://azurearcjumpstart.io/azure_jumpstart_arcbox/
