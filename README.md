VM dependency resolution supported parallel shutdown/start (Azure PS run book)
==============================================================================

            

**Introduction**


This PowerShell workflow based Azure run book can be deployed to azure automation in order to support scheduled RM VM shutdown/start in parallel, it also supports VM dependency resolution using simple PS hash table object.


 


**Scenarios
**DevOps engineers or Developers can import this runbook and customise it in order to schedule shutdown and start of Azure VMs under a certain resource group. It supports parallel shutdown/start, skip action on weekends, public holiday and/or
 a list of skipped VMs. Most importantly, it can support the VM dependency declarations in simple powershell hash table data structure for auto-resolution of dependencies when shuting down or starting VMs in batches.


 


**Script**


The script can be imported as Azure Automation runbook.


There are two default parameters and one variable that are mandatory for running.


 

 

 


The $Shutdown paramter is a boolean type which denotes whether to shutdown VMs (specify $Shutdown = $True) or start VMs ($Shutdown = $False)


The $AzureResourceGroup is the resource group name.


 


 

 

 


It is recommended to use a Azure Automation Credential, here it is named 'DefaultAzureCredential'. Name can be specified when the credentials are uploaded to Azure Automation. The credentials should have permission to run get-azurermvm and start/shutdown
 vms within the resource group.


 


Further there are other variable you would need to configure.


 

 

 


$SkippedVMs is a PowerShell string array contains the names of the VMs that should not participate into the shutdown / start actions.


$pubHolidays is a PowerShell string array list all known public holidays using dd/MM/yyyy format.


$dependencyGraph is used to Specify vm dependencies using a hashtable data structure, currently no nested hashtables is allowed. The key for the hashtable denotes the vm that depends on other vm(s) of which names appear as equivlant hashtable values.
 e.g. jenkins master/slave depends on puppet master, and jenkins slave further depends on jenkins master.


 


**Customisation**


Further customisations can be done to the code including enhancing the DAG topological sorting algorithm.


 


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
