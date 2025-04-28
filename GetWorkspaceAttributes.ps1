
Connect-PowerBIServiceAccount

# check if we are logged in and if not login to Power BI
try {
        get-powerbiaccesstoken | Out-Null
    }
catch {
        Connect-PowerBIServiceAccount | Out-null
    }


# Define the input workspace list 
$wsFilePath = ".\activityevents.csv"
$csvFilePath = ".\WorkspaceAttributes.csv"
# Read workspaces list 
$workspaceIds = Import-Csv -Path $wsFilePath 
$workspacesid = @()  # Initialize the array to hold workspace IDs
try {
    foreach ($row in $workspaceIds){
        $workspaceId = $row.WorkspaceId
        $workspacesid += $workspaceId
    }
        # Remove duplicates
        $workspacesid = $workspacesid | Sort-Object -Unique
    Write-Host "Workspacesid count: $($workspacesid.count)"
   # Write-Host "Workspaces: $($workspaces)"
} catch {
    Write-Host "Error getting workspaces: $_"
}

$workspaceDetails = New-Object System.Collections.Generic.List[object]

# Get all active premium workspaces list
try {
    $workspaces = Get-PowerBIWorkspace -Scope Organization -All 
    #-Filter "isOnDedicatedCapacity eq true and tolower(state) eq 'active'"
} catch {
    Write-Host "Error getting workspaces: $_"
    return
}

# Filter workspaces to match the IDs in $workspaceIds
$workspaces = $workspaces | Where-Object { $workspacesid -contains $_.Id }



 Write-Host "Workspaces count: $($workspaces.count)"
 Write-Host "Workspaces: $($workspaces)"
foreach ($workspace in $workspaces)
{
    try
    {
    $owners = $workspace.Users | Where-Object { $_.AccessRight -eq 'Admin' } | ForEach-Object { $_.UserPrincipalName }   
        Write-Host "Workspace: $($workspace.Name)"
        # create custom object
        $item = [PSCustomObject] @{
            WorkspaceId = $workspace.ID
            WorkspaceName = $workspace.Name
            Type = $workspace.Type
            State = $workspace.State
            IsReadOnly = $workspace.IsReadOnly
            IsOrphaned = $workspace.IsOrphaned
            IsOnDedicatedCapacity = $workspace.IsOnDedicatedCapacity
            CapacityId = $workspace.CapacityId
            Owners = $owners -join ","
        }
     $workspaceDetails.Add($item)
    } catch {
    Write-Host "Error processing workspace $($workspace.ID): $_"
            }

}
# Export the data to CSV
try {
    $workspaceDetails | Export-Csv -Path $csvFilePath -NoTypeInformation
    Write-Host "Workspace details exported to $csvFilePath"
} catch {
    Write-Host "Error exporting to CSV: $_"
}