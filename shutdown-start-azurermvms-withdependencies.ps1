workflow shutdown-start-azurermvms-withdependencies
{    
    Param(        
        [bool] $Shutdown = $True,
        [string] $AzureResourceGroup = 'resource-group-name'          
    )
    
    # Specify VMs under the resource group that will not participate into the shutdown or start action
    $SkippedVMs = @("skippedvmname1";"skippedvmname2";"skippedvmname3";"skippedvmname4";"skippedvmname5")
    # Specify public holidays in dd/MM/yyyy format, here australian victoria public holidays are used as samples
    $pubHolidays = @("14/04/2017";"17/04/2017";"25/04/2017";"12/06/2017";"29/09/2017";"07/11/2017";"25/12/2017";"26/12/2017";"01/01/2018";"26/01/2018";"12/03/2018";"30/03/2018";"02/04/2018";"25/04/2018";"11/06/2018";"06/11/2018";"25/12/2018";"26/12/2018")

    # Specify vm dependencies using a hashtable data structure, currently no nested hashtables is allowed. The key for the hashtable denotes the vm that depends on other vm(s) of which names appear as equivlant hashtable values. e.g. jenkins master/slave depends on puppet master, and jenkins slave further depends on jenkins master
    $dependencyGraph = @{"jenkins-master-vm"=@("ldap-vm";"puppet-master-vm"); "jenkins-slave-vm"=@("jenkins-master-vm";"puppet-master-vm")}

    # Azure automation uses UTC time to run the runbook jobs, thus may need to convert to local time for weekend and public holiday check to be accurate as per the current timezone -- note, the schedule under the azure automation usually will take into account the local timezone.
    $currentUTC = Get-Date
    $current = [System.TimeZoneInfo]::ConvertTimeFromUtc($currentUTC.ToUniversalTime(), [System.TimeZoneInfo]::FindSystemTimeZoneById('AUS Eastern Standard Time'))

    # No Action on Weekends or Victora public holiday
    if ((($current).DayOfWeek -ne 'Saturday') -and (($current).DayOfWeek -ne 'Sunday') -and ($pubHolidays -notcontains ($current).tostring('dd/MM/yyyy')))
    {   
        # Get the credential from the azure automation with permission to run get Get-AzureRmVM and Start/Stop VMs.
        $Cred = Get-AutomationPSCredential -Name 'DefaultAzureCredential'
        Add-AzureRmAccount -Credential $Cred

        if ($Shutdown -eq $True){
            Write-Output "Stopping VMs in '$($AzureResourceGroup)' resource group";
        }
        else {
            Write-Output "Starting VMs in '$($AzureResourceGroup)' resource group";
        }
        
        # Get existing VMs under the resource group and their PowerStates
        $VMs = Get-AzureRmVM -Status -ResourceGroupName $AzureResourceGroup;
        

        ## Resolve dependency based on DAG generated from the hashtable        
        $servers = @()        
        
        $keys = $dependencyGraph.Keys
        
        $servers += $keys
        
        ForEach ($key in $dependencyGraph.Keys)
        {   
            $servers += $dependencyGraph[$key]    
        }        
        
        $servers = $servers | Select -Unique
               

        $vertices = @()    
        $keysasvertices = @()
        $batchVertices = @()

        ForEach ($VM in $VMs)
        {
            if ($servers -notcontains $VM.Name){
                $batchVertices += $VM
            }
        }

        $batchId = 0
        $batch = @{}
        While ($vertices.Count -lt $servers.Count)
        {
            $foundvertices = $False

            $vcandidates = (Compare-Object $servers $vertices) | Where-Object SideIndicator -eq '<=' | Select -ExpandProperty InputObject            
              
            ForEach ($vcandidate in $vcandidates)
            {                   

                if ($keys -notcontains $vcandidate){
                    $vertices += $vcandidate

                    ForEach ($VM in $VMs)
                    {                           
                        if ($vcandidate -eq $VM.Name){ 
                            $batchVertices += $VM                            
                        }
                    }

                    $foundvertices = $True                    
                }
            } 
            
            # vertices batch
            if ($foundvertices){           
               $batchId += 1

               $batch += @{$batchId=$batchVertices}               
            }            

            $foundKeyvertices = $False
            $keysasverticestoadd = @()  
            $batchVertices = @()     
            ForEach ($key in $keys){
                if (((Compare-Object $dependencyGraph[$key] $vertices) | Where-Object SideIndicator -eq '<=' | Select InputObject).Count -eq 0)
                {
                    $keysasvertices += $key
                    $keysasverticestoadd += $key
                    
                    ForEach ($VM in $VMs)
                    {   
                        if ($key -eq $VM.Name){ 
                            $batchVertices += $VM                            
                        }
                    } 

                    $foundKeyvertices = $True
                    
                }
            }
            
            $vertices += $keysasverticestoadd

            $keys = (Compare-Object $keys $keysasvertices) | Where-Object SideIndicator -eq '<=' | Select -ExpandProperty InputObject

            # vertices batch
            if ($foundKeyvertices){
                $batchId += 1

                $batch += @{$batchId=$batchVertices}
            }

            if ($foundvertices -eq $False -and $foundKeyvertices -eq $False){            
                # not an acyclic graph, must exit
                Write-Error ("The dependenceGraph defined has cyclic reference, it must be corrected.") 
                exit
            }

            $batchVertices = @()  
        }

        
        if ($Shutdown -eq $True) {
            For ($i=$batch.keys.count; $i -gt 0; $i--)
            { 
                Write-Output "Parallel Execution Batch: $($batch.keys.count - $i + 1)"
                ForEach -Parallel ($VM in $batch[$i]) {        
                    if ($SkippedVMs -notcontains ($VM.Name))
                    {
                        if ($VM.PowerState -like "*running"){
                            Write-Output "Stopping '$($VM.Name)' ...";             
                            Stop-AzureRmVM -ResourceGroupName $AzureResourceGroup -Name $VM.Name -Force;
                        }
                    }
                }               
            }
        }else
        {
            For ($i=1; $i -le $batch.keys.count; $i++)
            { 
                Write-Output "Parallel Execution Batch: '$($i)'"
                ForEach -Parallel ($VM in $batch[$i]) {
                    if ($SkippedVMs -notcontains ($VM.Name))
                    {
                        if ($VM.PowerState -like "*deallocated") {        
                            Write-Output "Starting '$($VM.Name)' ...";			
                            Start-AzureRmVM -ResourceGroupName $AzureResourceGroup -Name $VM.Name;
                        }  
                     }
                }                
            }
        }
    }else
    {
        Write-Output ("No VM start/shutdown action on " + $current);
    }
}