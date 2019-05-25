# Remove-SCCMClient

## What is this?
This is a Powershell script designed to speed up the process with repairing broken SCCM clients. One of the bigger steps to this is removing the client, and correcting Firewall rules in the event of configuration drift, and then from the ConfigMan console sending a remote re-install.

When you do this manually, even if you know what you're doing,it takes about 15-20 minutes. But let's be honest, if you're running an SCCM server, you're not a small anymore, and you have to support something like 100 client machines on your network. So if you end up with 10 clients marked as broken, that's a lot of time down the drain for something that should be automated.

All this script focuses on is removing the SCCM client, cleaning up its artifacts in the various locations in the File System, and Registries, and finally setting up the Firewall rules to allow the to-be reinstalled client so it is able to do its job without networking shenannigans. All of this, while disabling services so the artifacts aren't locked when attempting to delete them.

The details in the logic are available in the source code. And yes, you're free to modify this for your environment. I am only looking to save SysAdmin/System Engineer's time when handling naughty SCCM clients :)

## How to install
Pretty straightforward, only two steps:
1) Clone this repo, or download the zip file
2) Download ccmclean.exe, and place it in the "tools" folder of this toolkit. Your folder structure would need to look like this:

**Remove-SCCMClient**
-Readme.md
-Remove-SCCMClient.ps1
    **=> tools**
    -cclmean.exe

This script relies on the use of ccmclean.exe, and for my own safety, I have chosen to not include it in the latest commits going forward. You will need to download it yourself.

You can download the SMS 2003 Management pack, which includes
ccmlean.exe here: https://www.microsoft.com/en-us/download/details.aspx?id=17145

## How to use:
**Note**: The root folder and all of the contents of this script need to be on the host machine that you plan on removing the SCCM client on. So if you plan on removing a client from a remote host, just copy the Remove-SCCMClient to C:\ or whereever via UNC, USB, or whatever.

Unfortunately, a limitation of the ccmclean.exe tool, is that you need to interact with the prompts as they come up. The silent running feature doesn't appear to work. So if you're working with a remote host, an RDP session is required.

1) Using Powershell as administrator, invoke the scriptfile through the standard *.\Remove-SCCMClient.ps1* method.
**Note**: Make sure the host has enabled the use of scripts, if they don't, you will need to temporarily change the value with the use of the *Set-ExecutionPolicy* cmdlet.
2) Watch the script progress, and close any exception messages ccmclean.exe throws.
3) Once the script is done, you can run ccmclean.exe manually again if you'd like, or you can go ahead and restart the host machine.
**Note**: Some folders may be left behind after running this script, this okay if you plan on reinstalling the SCCM client again.

That's it, it's dead simple.

## Future To-Do items
- Other things I want to do:
    - Redo the firewall rules function to use the Powershell cmdlets instead. This will futureproof this tool for Powershell Core
    - Create the internal helpfile and list off what things can be ignored, and what things need attention. This will improve tenfold when Benny's logging module is incorporated
    - Incorporate Benny's Error-Logging module so we can have the console output write to a file in a standardized matter.

## What's new?
###0.5
- Initial test-build. This is a bludgen tool to uninstall sccm for now, still need to do some clean up work by using the tools the guide suggests, and restart the machine manually

###v0.6
- Script calls upon ccmsetup \uninstall, waits, and kills process
- Script calls upon ccmclean
- Script calls upon .Net Framework 4.6.1 as per the instructions in confluence page
- Added some logic so functions only execute now when their parent tasks have finished

###v0.6.1
- Removed most of the logic. Not happy with the reliability of the detection since the initial 4 services are seldom-enumerated. It is better to leave as-is.
    - That, but also checking if a process is not running is redundant to check. We kill the process as part of the start-up logic anyway, there is no need to check if its there. It is more worthwhile to retry if something fails, and then append a message to a log for an IT team member to investigate

###V0.6.2 (CURRENT)
- Removed ccmclean.exe, and the .NET install in the "tools directory".