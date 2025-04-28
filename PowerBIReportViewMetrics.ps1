# Install required modules if not already installed and verify permissions
# Install-Module -Name MicrosoftPowerBIMgmt

# Connect to Power BI service using admin credentials


$Config = @{
    Environment                = "Public"
    AdEnvironment              = "AzureCloud"

    SinkType                   = "CSV"
    Sink                       = "out"
    SinkSchema                 = "dbo"

    AuditLogDays               = 90
    AuditLogBatchHours         = 24

    ApiGatewayUri              = "https://api.powerbi.com"

}

Write-Host "Exporting Audit Log for $($Config.AuditLogDays) days..." -Config $Config

$Config.AuthContext = Connect-PowerBIServiceAccount -Environment $Config.Environment

[DateTime]$start = (get-date).AddDays(-$Config.AuditLogDays).Date
[DateTime]$end = (get-date).AddDays(-1).Date

[DateTime]$currentStart = $start
[DateTime]$currentEnd = $start

$totalDays = ($end - $start).TotalDays + 1

$csvFilePath = ".\activityevents.csv"
$workspaceDetails = New-Object System.Collections.Generic.List[object]


$continueToNextInterval = $True
while ($continueToNextInterval) 
{
    $auth_header = @{
        'Content-Type'  = 'application/json'
        'Authorization' = Get-PowerBIAccessToken -AsString
                    }
    try {
        $currentEnd = $currentStart.AddHours(24).AddSeconds(-1)
        $processingDay = [Math]::Round(($currentStart - $start).totalDays, 0) + 1
        
        if ($currentEnd -gt $end ) {
            break
                                    }
        Write-Host "Retrieving audit logs for $($currentStart)" -Config $Config
        $currentCount = 0
        $filter= '$filter'
        $uri_auditlog = "$($Config.ApiGatewayUri)/v1.0/myorg/admin/activityevents?startDateTime='$($currentStart.ToString("yyyy-MM-ddTHH:mm:ssZ"))'&endDateTime='$($currentEnd.ToString("yyyy-MM-ddTHH:mm:ssZ"))'&$filter=Activity eq 'ViewReport'"
        Write-Host "uri_auditlog = $uri_auditlog"
        $queryError = $null
        $response = (Invoke-RestMethod -Uri $uri_auditlog -Headers $auth_header -Method GET -ErrorVariable queryError)
        
 if ($null -eq $response) {
                    $continueToNextInterval = $false
                    $currentOffset = [Math]::Ceiling(((get-date) - $currentEnd).TotalDays)
                    break
                        }
                $all_auditlog = $response.ActivityEventEntities
                $continuationToken = $response.continuationToken

                while (![string]::IsNullOrEmpty($continuationToken)) 
                {
                    $uri_innerresponse = $response.continuationUri
                    $response = (Invoke-RestMethod -Uri $uri_innerresponse -Headers $auth_header -Method GET)
                    if ($null -eq $response) {
                        $continueToNextInterval = $false
                        $currentOffset = [Math]::Ceiling(((get-date) - $currentEnd).TotalDays)
                        break
                                            }
                
                    $all_auditlog += $response.activityEventEntities   
                    $currentCount = $response.activityEventEntities.Count
                    if ($currentCount -gt 0) {
                        $message = "Retrieved $($currentCount) audit records"
                        Write-Host $message -Config $Config 
                                            }
                    $continuationToken = $response.continuationToken
                } #while 69

                # Required in order to make a structured list to iterate over to include all fields. 
                $CsvObjects = @()       
                foreach ($activity in $all_auditlog) 
                {
                    #if ($activity.Activity -eq 'ViewReport')
                    #{                    
                    $CsvObject = [PSCustomObject]@{
                        Id                                = $activity.Id 					
                        RecordType                        = $activity.RecordType 			 
                        CreationTime                      = $activity.CreationTime      
                        Operation                         = $activity.Operation         
                        OrganizationId                    = $activity.OrganizationId    
                        UserType                          = $activity.UserType          
                        UserKey                           = $activity.UserKey           
                        Workload                          = $activity.Workload          
                        UserId                            = $activity.UserId            
                        ClientIP                          = $activity.ClientIP          
                        UserAgent                         = $activity.UserAgent         
                        Activity                          = $activity.Activity          
                        ItemName                          = $activity.ItemName          
                        WorkSpaceName                     = $activity.WorkSpaceName     
                        DatasetName                       = $activity.DatasetName       
                        ReportName                        = $activity.ReportName        
                        CapacityId                        = $activity.CapacityId        
                        CapacityName                      = $activity.CapacityName      
                        WorkspaceId                       = $activity.WorkspaceId       
                        AppName                           = $activity.AppName           
                        ObjectId                          = $activity.ObjectId          
                        DatasetId                         = $activity.DatasetId         
                        ReportId                          = $activity.ReportId          
                        IsSuccess                         = $activity.IsSuccess         
                        ReportType                        = $activity.ReportType        
                        RequestId                         = $activity.RequestId         
                        ActivityId                        = $activity.ActivityId        
                        AppReportId                       = $activity.AppReportId       
                        DistributionMethod                = $activity.DistributionMethod
                        ConsumptionMethod                 = $activity.ConsumptionMethod 
                        TableName                         = $activity.TableName
                        DashboardName                     = $activity.DashboardName
                        DashboardId                       = $activity.DashboardId 
                        Datasets                          = ($activity.Datasets | ConvertTo-Json)
                        DataflowId                        = $activity.DataflowId
                        DataflowName                      = $activity.DataflowName
                        DataflowRefreshScheduleType       = $activity.DataflowRefreshScheduleType
                        DataflowType                      = $activity.DataflowType
                        EmbedTokenId                      = $activity.EmbedTokenId
                        CustomVisualAccessTokenResourceId = $activity.CustomVisualAccessTokenResourceId
                        CustomVisualAccessTokenSiteUri    = $activity.CustomVisualAccessTokenSiteUri
                        DataConnectivityMode              = $activity.DataConnectivityMode
                                             }
                    $CsvObjects += $CsvObject
                    $workspaceDetails.Add($CsvObject)
                    #}
                }
        } #try ln45
        catch {
            Write-Host "Error reading audit data"
        }                
  
            $message = "Retrieved $($all_auditlog.Count) records for the current time range"
            Write-Host $message -Config $Config
                
            $currentStart = $currentEnd.AddSeconds(1)
 }  #While ln 79

 try {
    $workspaceDetails | Export-Csv -Path $csvFilePath -NoTypeInformation
    Write-Host "Activity events are extracted to $csvFilePath"
} catch {
    Write-Host "Error exporting to CSV: $_"
}

