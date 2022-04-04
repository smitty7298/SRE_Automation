# **Remove-Snapshots**

  

## This simple Remove-Snaphots script enables the removal of old VM snapshots that exist in vCenter 

    

Remove-Snapshots was written to automate the removal of outstanding snapshots on VMs in vCenter. 

  

Version 1.0 completes the following items:

- Removal of all snapshots in vCenter, by default for all VMs and for snapshots older than 30 days

- Error catching and an email sent with the results of the snaphot removal 


 

### **Public Functions**

  
------------

  

There is only one function exposed publicly, as this was written with the sole purpose of removing snapshots in vCenter and emailing the results for logging. 

  

**Remove-Snapshots** This is the main command used to remove the snapshots in vCenter. It requires all SMTP and vCenter parameters to be passed to it. 

  
This function has many parameters.
  
**SMTPServer**
- The SMTP server to relay the email to.

**SMTPSender**
- The FROM address of the email sender.

**SMTPDelivery**
- The TO address of the email recipient.

**SMTPPassword**
- An optional parameter in the case that you need to pass the SMTPDelivery password to the script for the SMTP relay.

**vCenter**
- IP or URL of the vCenter Server.

**vCenterUser**
- vCenter account that has proper permissions to remove snapshots from the VMs.

**vCenterPassword**
- Password for vCenterUser.

**VM**
- Optional search string for the VM(s) to remove the snapshots from. Default is all.

**Days**
- Optional int to specify the minimum age in days for the snapshots that need deleted. Default is 30.


**Examples**

The following example uses the minimum required perameters. This assumes no password is needed for SMTP, all VMs will be scanned, and snapshots older than 30 days will be removed:

```powershell
RemoveSnapshots.ps1 -SMTPServer "smtp.office365.com" -SMTPSender "security.portal@dizzion.com" -SMTPDelivery "tyler.smith@dizzion.com" -vCenter "thelab.dizzion.com" -vCenterUser "administrator@vsphere.local" -vCenterPassword "password123" 
```

This second example uses the all optional perameters. This assigns a password for the SMPTDelivery account, only VMs with "Z1000" in their name will be scanned, and snapshots older than 100 days will be removed.  
  
```powershell
RemoveSnapshots.ps1 -SMTPServer "smtp.office365.com" -SMTPSender "security.portal@dizzion.com" -SMTPPassword "emailPassword123" -SMTPDelivery "tyler.smith@dizzion.com" -vCenter "thelab.dizzion.com" -vCenterUser "administrator@vsphere.local" -vCenterPassword "password123" -VM "*Z1000*" -Days 100
```
  



### **Private Functions**

  

------------

These functions are not exposed when the module is imported. These functions are executed by calls from the public functions.

**Send-EmailResults**

A wrapper function for Send-MailMessage based on whether or not the SMTP password was provided. 
