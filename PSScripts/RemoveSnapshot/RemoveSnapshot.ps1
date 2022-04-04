
<#
.SYNOPSIS
    This script/function scans the target vCenter for snapshots older than X (default 30) amount of days, removes them, and reports results via email. 

.DESCRIPTION
    This script uses PowerCLI to connect to a vCenter instance in order to clean up old snapshots. Credentials and information for the SMTP and vCenter server instances are passed in via the parameters. 
    You can also specify the age, in days, of snapshots that you would like to remove from vCenter (default 30) by passign the Days perameter. If you would like to specify the naming convention for the VMs
    to remove the snapshots from, you can do so by passing the VM value as a parameter (default is all VMs). The script will remove all snapshots older than X days in vCenter, and provide and email that 
    reports on the results. 

.PARAMETER SMTPServer
    The SMTP server to relay the email to.

.PARAMETER SMTPSender
    The FROM address of the email sender.

.PARAMETER SMTPDelivery
    The TO address of the email recipient.

.PARAMETER SMTPPassword
    An optional parameter in the case that you need to pass the SMTPDelivery password to the script for the SMTP relay. 

.PARAMETER vCenter
    IP or URL of the vCenter Server.

.PARAMETER vCenterUser
    vCenter account that has proper permissions to remove snapshots from the VMs.

.PARAMETER vCenterPassword
    Password for vCenterUser.

.PARAMETER VM
    Search string for the VM(s) to remove the snapshots from. Default is all.

.PARAMETER Days
    The minimum age in days for the snapshots that need deleted. Default is 30. 

.EXAMPLE
    The example uses the minimum required perameters. This assumes no password is needed for SMTP, all VMs will be scanned, and snapshots older than 30 days will be removed. 
    PS C:\> RemoveSnapshots.ps1 -SMTPServer "smtp.office365.com" -SMTPSender "security.portal@dizzion.com" -SMTPDelivery "tyler.smith@dizzion.com" -vCenter "thelab.dizzion.com" -vCenterUser "administrator@vsphere.local" -vCenterPassword "password123" 

.EXAMPLE
    The example uses the all optional perameters. This assigns a password for the SMPTDelivery account, only VMs with "Z1000" in their name will be scanned, and snapshots older than 100 days will be removed. 
    PS C:\> RemoveSnapshots.ps1 -SMTPServer "smtp.office365.com" -SMTPSender "security.portal@dizzion.com" -SMTPPassword "emailPassword123" -SMTPDelivery "tyler.smith@dizzion.com" -vCenter "thelab.dizzion.com" -vCenterUser "administrator@vsphere.local" -vCenterPassword "password123" -VM "*Z1000*" -Days 100

.NOTES
    Author: Tyler Smith
    Last Edit: 2022-04-04
    Version 1.0 - Quick and dirty script to show I'm not a dumb-dumb for the SRE position. 
    Version 1.1 - Cleaned up some use of aliases 

#>
 
 #Parameters
 param(
        [Parameter(
            Mandatory=$True
        )]
        [string] $SMTPServer,       
        [string] $SMTPSender,
        [string] $SMTPDelivery,
        [string] $vCenter,
        [string] $vCenterUser,
        [string] $vCenterPassword,

     
        [Parameter(
            Mandatory=$False
        )]
        [string] $SMTPPassword,
        [string] $VM="*",
        [int] $Days=30
    )

  
# Variables
$location = Get-Location 
$today = Get-Date

#A wrapper function to handle the case of whether or not we are using credentials to send the email. Found myself Re-writing this block a bit thorughout the script
function Send-EmailResults{
 param(
        [Parameter(
            Mandatory=$True
        )]
        [string] $SmtpServer,
        [string] $From,
        [string] $To,
        [string] $Body,
        [string] $Subject,
        [Parameter(
            Mandatory=$False
        )]
        [string]
        $Password
        )
        
    if($Password){
        [securestring]$pw = ConvertTo-SecureString $Password -AsPlainText -Force
        [pscredential]$credSMTP = New-Object System.Management.Automation.PSCredential ($From, $pw)
        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SmtpServer -Credential $credSMTP -UseSsl -Port 587
    }
    else{
        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SmtpServer
    } 
             
}

# Load powercli and install it if I don't have it (I might be overthinking this).
if(!(Get-Module -ListAvailable -Name "VMware.PowerCLI")){[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Install-Module -scope CurrentUser -force -confirm:$false -SkipPublisherCheck}

#Let's create the log file that is used to send the reporting email. If we run into an error here then we really have some problems. 
try{
    Write-Output "This email has been generated from the Automated Snapshot Removal process running on $env:COMPUTERNAME on $today. The below snapshots have been removed from the system:" | Out-File $location\SnapshotLog.txt -Append -ErrorAction Stop
}

catch{
    Write-Host "Failed to create log file."
    Email-Results -SmtpServer $SMTPServer -To $SMTPDelivery -From $SMTPSender -Subject "Automated Snapshot Removal Report Failed" -Body "This email has been generated from the Automated Snapshot Removal process running on $env:COMPUTERNAME. Unable to create the log file used for reporting. Please investigate. `n`nError: $_.Exception.Message" -Password $SMTPPassword
    Break
}

# Connect to vSphere vCenter Server.
try{
    connect-viserver -server $vCenter -user $vCenterUser -Password $vCenterPassword -ErrorAction Stop
}
catch{
    Write-Host "Failed Connecting to VSphere Server."
    Email-Results -From $SMTPSender -To $SMTPDelivery -Subject "Automated Snapshot Removal Report Fialed" -Body `
    "This email is being sent from the Automated Snapshot Removal process running on $env:COMPUTERNAME. Unable to connect ot vCenter with IP/URL: $vCenter. Please investigate. `n`nError: $_.Exception.Message" -SmtpServer $SMTPServer -Password $SMTPPassword
    Break
 }

# Check to see if there are snapshots that need cleaning up, then do it to it starting with the oldest.
if($oldSnapshots= get-snapshot -vm $VM | Where-Object {$_.Created -lt (Get-Date).AddDays(-$Days)} | Sort-Object -Descending){
    foreach ($snapshot in $oldSnapshots){
        try{
        $size=$snapshot.SizeGB #Getting this stat now. This goes to 0 after Remove-Snapshot is run
        $snapshot | Remove-Snapshot -Confirm:$false -ErrorAction Stop 
        Write-Output $snapshot | Select-Object VM, Name, Description, @{Name="DaysSinceCreated";Expression={((Get-Date)-$_.Created).Days}},@{Name="Status";Expression={"Removed"}},@{Name="SnapshotSizeGB";Expression={$size}} | Out-File $location\SnapshotLog.txt -Append
        }
        
        catch{
        $thiserror= $_.Exception.Message 
        Write-Output $snapshot | Select-Object VM, Name, SizeMB, @{Name="DaysSinceCreated";Expression={((Get-Date)-$_.Created).Days}},@{Name="Status";Expression={$thiserror}} | Out-File $location\SnapshotLog.txt -Append
        }
    }
}
else{
    Write-Output "No Snapshots to clean up." | Out-File $logpath\Snapshots_$date.txt -Append
}
# Send snapshot log to email. Could make this pretty if I had more time/desire. The information being sent now works though. 
$emailbody = (Get-Content $location\SnapshotLog.txt | Out-String)
    Email-Results -From $SMTPSender -To $SMTPDelivery -Subject "Automated Snapshot Removal" -Body $emailbody -SmtpServer $SMTPServer -Password $SMTPPassword

# Exit VIM server session.
disconnect-viserver -server $vCenter -Confirm:$false
 
# Cleanup logs 
Remove-Item $location\SnapshotLog.txt -Confirm:$false -Force


