<#
 - The internal help file will go here, I will list off the things that will not be deleted, how they impact the cleanup
process (if they do), and what remediation action IT staff can undertake to resolve it.
- Other things I want to do:
    - Redo the firewall rules function to use the Powershell cmdlets instead. This will futureproof this tool for Powershell Core
    - Create the internal helpfile and list off what things can be ignored, and what things need attention. This will improve tenfold when Benny's logging module is incorporated
    - Incorporate Benny's Error-Logging module so we can have the console output write to a file.
        - This includes an ISO standard date convention, and other neat goodies that elminates a lot of the work this script will need for a useful logging feature
    - The functions are ordered for a specific reason. This is based on the SCCM client removal instructions. I need to add some extra logic to make sure they don't just fire off sequentially, but they do it if their dependency finishes its job first.

What's new?
v0.5
- Initial test-build. This is a bludgen tool to uninstall sccm for now, still need to do some clean up work by using the tools the guide suggests, and restart the machine manually
v0.6
- Script calls upon ccmsetup \uninstall, waits, and kills process
- Script calls upon ccmclean
- Script calls upon .Net Framework 4.6.1 as per the instructions in confluence page
- Added some logic so functions only execute now when their parent tasks have finished
v0.6.1
- Removed most of the logic. Not happy with the reliability of the detection since the initial 4 services are seldom-enumerated. It is better to leave as-is.
    - That, but also checking if a process is not running is redundant to check. We kill the process as part of the start-up logic anyway, there is no need to check if its there. It is more worthwhile to retry if something fails, and then append a message to a log for an IT team member to investigate
#>
$errorview = "categoryview"
$dirwin = "C:\Windows"
$dirccm = "$dirwin\ccm"
$dirccmcache = "$dirwin\ccmcache"
$dirccmsetup = "$dirwin\ccmsetup"
$dirrepo = "$dirwin\System32\wbem\Repository" #Wildcards appended in case there are duplicates
$serccm = "ccmsetup" #Only appears if ccmsetup.exe is running
$serSMS = "ccmexec" #SMS Agent Host
$sersmtsmgr = "smstsmgr" #ConfigMgr Task Sequence Manager
$sercmrcservice = "cmrcservice" #Configuration Manager Remote Control
$serwmi = "winmgmt" #Windows Management Instrumentation
$regpath = "HKLM:\SOFTWARE\Microsoft"
$regccm = "$regpath\CCM"
$regccmsetup = "$regpath\CCMSetup"
$regsms = "$regpath\SMS"
Function Uninstallclient
{
    Write-host ""
    Write-Host "***Invoking ccmsetup.exe /uninstall, and waiting 30 seconds before begining rest of logic. Stand by...***"
    Write-host ""
    Try
    {
        Start-Process -FilePath "$dirccmsetup\ccmsetup.exe" -ArgumentList "/uninstall" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 30
        Stop-Process -Name ccmsetup -force -ErrorAction SilentlyContinue
    }
    Catch
    {
        Write-host ""
        Write-Host "Something went wrong in invoking ccmsetup.exe, please verify that the $dirccmsetup\ccmsetup.exe still exists."
        Write-Host "This step is optional. This can be ignored"
        Write-host ""
    }
}
<#Start ccmsetup.exe /uninstall, wait for 30 seconds, then stop it#>
Function Runccmclean
{
    Write-host ""
    Write-Host "***Invoking ccmclean.exe. Please action the prompts as they appear...***"
    Write-host ""
    Try
    {
        Start-Process -FilePath "$PSScriptRoot\tools\ccmclean.exe" -Wait -ErrorAction SilentlyContinue
    }
    Catch
    {
        Write-host ""
        Write-Host "Something went wrong in invoking ccmclean.exe, please verify that $PSScriptRoot\tools\ccmclean exists..."
        Write-host ""
    }
}
Function RunDotNetFW
{
    Write-host ""
    Write-Host "***Invoking .Net Framework 4.6.1 setup. Please action the window...***"
    Write-host ""
    Try
    {
        Start-Process -FilePath "$PSPath\tools\NDP461-KB3102436-x86-x64-AllOS-ENU.exe" -ErrorAction SilentlyContinue
    }
    Catch
    {
        Write-host ""
        Write-Host "Something went wrong in invoking .Net Framework 4.6.1 setup, please verify that $PSScriptRoot\tools\NDP461-KB3102436-x86-x64-AllOS-ENU.exe exists..."
        Write-host ""
    }
}
<#Start ccmclean, chose not to do it quietly so IT staff can see if it fails or not, and run it a few more times manually for good measure. I can always make this a quiet deployment, and a for loop with a corresponding a counter that increments up to 5 attempts #>
function StopService
{
    Param
    (
        [String]$servicetostop = ""
    )
    Stop-Service -Name $servicetostop -Force -ErrorVariable serviceerror -ErrorAction SilentlyContinue
        If($serviceerror)
        {
            Write-host ""
            Write-Host ""$serviceerror[0]"Skipping..."
            Write-Host "Recommend either restarting machine or stopping the Service manually and running the script again"
            Write-host ""
        }
        Else
        {
            Write-host ""
            Write-Host "Successfully stopped $servicetostop"
            Write-host ""
        }
    Clear-Variable -Name serviceerror -ErrorAction SilentlyContinue
}
<#
- Attempts to stop the Service. Use an error variable to catch any errors, and present through a tidy errorview.
- And clear up the variable in case the script is run again.
#>
function DeleteFolder
{
    Param
    (
        [String]$foldertodelete = ""
    )
    ForEach($folder in (Get-ChildItem -Path $foldertodelete))
    {
        Remove-Item -Path $folder.FullName -Force -Recurse -ErrorVariable deletefolerror -ErrorAction SilentlyContinue
        If($deletefolerror)
        {
            Write-host ""
            Write-Host $deletefolerror[0]
            Write-Host "For more information, refer to the help file for the directory that has failed to delete"
            Write-host ""
            Continue
        }
        Write-host ""
        Write-Host "Successfully deleted"$folder.Name""
        Write-host ""
    }
    Clear-Variable -Name deletefolerror -ErrorAction SilentlyContinue
}
<#
- Use a Get-ChildItem to enumerate the items needed for the ForEach loop. Use the .FullName member for the $folder items so that the -Path parameter actually has a path to use for the Remove-Item cmdlet
- Use an error variable to catch any errors, and present through a tidy errorview.
- If there is an error, it will display the Powershell-provided categoryview for the error. It would be something like "the path could not be deleted" along with a reason why.
# Along with that error message and path, there is a mention of consulting the help file for this script. In there, I will have documented a list of directories and files that will fail to delete in this script, and whether or not it is worth deleting them yourself.
- The use of the .Name member is used for legibility reasons. Not compulsary.
- Clear up the variable in case the script is run again.
#>
function SetFirewallrules
{
    netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'windows management instrumentation (wmi)', and enabling it"
    netsh advfirewall firewall add rule dir=in name="DCOM" program=%systemroot%\system32\svchost.exe service=rpcss action=allow protocol=TCP localport=135
    netsh advfirewall firewall add rule dir=in name ="WMI" program=%systemroot%\system32\svchost.exe service=winmgmt action = allow protocol=TCP localport=any
    netsh advfirewall firewall add rule dir=in name ="UnsecApp" program=%systemroot%\system32\wbem\unsecapp.exe action=allow
    netsh advfirewall firewall add rule dir=out name ="WMI_OUT" program=%systemroot%\system32\svchost.exe service=winmgmt action=allow protocol=TCP localport=any
    netsh advfirewall firewall add rule dir=out name ="CCMSetup" program=%systemroot%\ccmsetup\ccmsetup.exe service=winmgmt action=allow protocol=TCP localport=any
    netsh advfirewall firewall add rule dir=out name ="CCM" program=%systemroot%\CCM\ccmexec.exe service=winmgmt action=allow protocol=TCP localport=any
    netsh advfirewall firewall add rule name="HTTP" dir=in action=allow protocol=TCP localport=80
    netsh advfirewall firewall add rule name="SSL" dir=in action=allow protocol=TCP localport=443
    netsh advfirewall firewall add rule name="SQL Browser" dir=in action=allow protocol=TCP localport=1434
    netsh advfirewall firewall set rule group="Remote Administration" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'Remote Administration', and enabling it"
    netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'File and Printer Sharing', and enabling it"
    netsh advfirewall firewall set rule group="Remote Service Management" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'Remote Service Management', and enabling it"
    netsh advfirewall firewall set rule group="Performance Logs and Alerts" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'Performance Logs and Alerts', and enabling it"
    Netsh advfirewall firewall set rule group="Remote Event Log Management" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'Remote Event Log Management', and enabling it"
    Netsh advfirewall firewall set rule group="Remote Scheduled Tasks Management" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'Remote Scheduled Tasks Management', and enabling it"
    netsh advfirewall firewall set rule group="Remote Volume Management" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'Remote Volume Management', and enabling it"
    netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'Remote Desktop', and enabling it"
    netsh advfirewall firewall set rule group="Windows Firewall Remote Management" new enable =yes
        Write-Host ""
        Write-Host "Creating group 'Windows Firewall Remote Management', and enabling it"
    netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes
        Write-Host ""
        Write-Host "Creating group 'windows management instrumentation (wmi)', and enabling it"
}
<#
 #Rules adapted from original script: SCCMfirewall.ps1
 #Update this function to use powershell cmdlet equivalent
#>
function DeleteRegKey
{
    Param
    (
        [String]$regkeytodelete = ""
    )

    ForEach($subkey in (Get-ChildItem -Path $regkeytodelete -ErrorVariable enumerror -ErrorAction SilentlyContinue))
    {
        Remove-Item -Path $subkey.PSPath -Force -Recurse -ErrorVariable deleteregerror -ErrorAction SilentlyContinue
        If($deleteregerror)
        {
            write-host ""
            Write-Host $deleteregerror[0]"Skipping..."
            Write-host "For more information, refer to the help file for the subkey that has failed to delete"
            Write-host ""
            Continue
        }
        Write-host ""
        Write-Host "Successfully deleted"$subkey.Name""
        Write-host ""
    }
    If($enumerror)
    {
        Write-host ""
        Write-host $enumerror[0].CategoryInfo.TargetName"Failed to delete, skipping..."
        Write-host "For more information, refer to the help file for the subkey that has failed to delete"
        Write-host ""
    }
    Clear-Variable -Name deleteregerror -ErrorAction SilentlyContinue
    Clear-Variable -Name enumerror -ErrorAction SilentlyContinue
}
<#
Author's Note:
#The condition that ForEach uses to create its list will throw an error if trying to enumerate registry keys that it does not have sufficient privilege to.
#This is due to a subtle difference in how registry hives are treated in Powershell as opposed to folder items, which you can.
#The logic in the loop will still work, but having it visible is not nice to look at.
#So I once again caught it with an error variable and had to set its catch outside the loop. Unfortunately, you cannot pass
#the error variable into the ForEach loop's catch as the logic being tested is outside the loop in the first place.
#Now back to the comments...!
- Enumerate the registry key and subkeys in the specified path for the ForEach loop
- Delete all items in the key/subkey path. The use of the .PSPath member is required for, once again, the quirks of Registry Hives in Powershell.
# When you query for a key, you are given the HKEY_#####_#### naming convention, and not the abbreviation. You could use a -replace parameter, but you're writing more code at that point. Using a
# PSPath however is a perfectly legimate parameter value when you're asking for the path to something. Unfortunately, registry keys like to be special and you can't use .path, or .name, to get anything useful
# out of it >:U
- Like in the deletefolder function, if an error is caught, it will advise what registry key failed to delete, and to consult the help file. In there will be the list of files that will require IT intervention.
#>

Uninstallclient
StopService -servicetostop $serccm
StopService -servicetostop $sersmtsmgr
StopService -servicetostop $serSMS
StopService -servicetostop $sercmrcservice

Runccmclean
#RunDotNetFW
#Disabled for now, until we determine if .Net Framework setup needs to be run, and if so, how.
Deletefolder -foldertodelete $dirccmsetup
Deletefolder -foldertodelete $dirccm
Deletefolder -foldertodelete $dirccmcache

DeleteRegKey -regkeytodelete $regccm
DeleteRegKey -regkeytodelete $regccmsetup
DeleteRegKey -regkeytodelete $regsms
#Make the if condition quiet, we just just want to enumerate if all the services have actually stopped before

    SetFirewallrules

    StopService -servicetostop $serwmi #This service should always be enumerated, so we can make a make the condition below a reality.
    If(Get-Service -Name $serwmi | Where-Object {$_.Status -eq "Stopped"})
    {
        DeleteFolder -foldertodelete $dirrepo
    }
#Stop WMI service, then delete Repository folder
Write-host ""
Write-Host "***The script has finished executing. Feel free to run ccmclean.exe again a few more times, or go ahead and restart the machine!***"
Write-host ""