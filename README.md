<!-- omit in toc -->
# DNS-O-Matic Updater

- [License](#license)
- [Download](#download)
- [Introduction](#introduction)
- [System Requirements](#system-requirements)
- [Installation](#installation)
  - [Initial Installation](#initial-installation)
  - [Subsequent Installations](#subsequent-installations)
- [About Network Profiles](#about-network-profiles)
- [Changing the DNS-O-Matic Credentials](#changing-the-dns-o-matic-credentials)
- [Uninstallation](#uninstallation)
- [Automatic DNS-O-Matic Updates using the Windows Task Scheduler](#automatic-dns-o-matic-updates-using-the-windows-task-scheduler)
- [Technical Details](#technical-details)

## License

**DNS-O-Matic Updater** is covered by the MIT license. See the file `LICENSE` for details.

## Download

https://github.com/Bill-Stewart/DNSOMaticUpdater/releases/latest

## Introduction

**DNS-O-Matic Updater** is a Windows application that updates the [DNS-O-Matic](https://www.dnsomatic.com/) service with the current Internet connection's external (public) IP address.

**DNS-O-Matic Updater** only performs DNS updates when connected to the Internet using a specific network profile. This is a safeguard to make sure you don't accidentally request updates when connected to a network than the one where updates should normally occur. (This is especially important for portable computers that connect to multiple networks.) See [About Network Profiles](#about-network-profiles) for more information.

## System Requirements

**DNS-O-Matic Updater** requires Windows 10/Windows Server 2016 or later.

## Installation

To start the installer, simply run the **DNSOMaticUpdater-Setup.exe** file.

### Initial Installation

The first time you run the installer, you will see the following option on the **Select Additional Tasks** wizard page:

* **Use scheduled task for updates**

This option is selected by default. If selected, the installer will create a scheduled task to update DNS-O-Matic every 5 minutes.

Before the installer completes, it will display a Windows PowerShell console (text-based) window and prompt for the network profile to use for updates (see [About Network Profiles](#about-network-profiles)) and your DNS-O-Matic credentials.

### Subsequent Installations

If you have already installed the application and you run the installer again, you will see the following options on the **Select Additional Tasks** wizard page:

* **Update network profile**
* **Update credentials**
* **Use scheduled task for updates**

If the name of your network profile has changed (for example, you replaced your WiFi router and your new network has a different name), select the **Update network profile** option to specify the name of the network profile you want to use. See [About Network Profiles](#about-network-profiles) for more information.

If you have changed your DNS-O-Matic password, select the **Update credentials** option to re-enter the DNS-O-Matic username and password.

If you want to perform DNS-O-Matic updates automatically every 5 minutes, select the **Use scheduled task for updates** option. Deselect this option to remove the scheduled task.

## About Network Profiles

As noted in the [Introduction](#introduction), DNS-O-Matic Updater only performs updates when the computer is connected to the Internet using a specific network profile. The network profile is the Windows operating system's name for the network to which the computer connects. Different networks will be labeled with different names. Windows automatically chooses names for wired and wireless networks. Wireless networks are usually named after the WiFi SSID.

When you first install **DNS-O-Matic Updater**, you will see a PowerShell console (text-based) window requesting the name of the network you want to use. It looks something like this:

```
Please select a network profile for performing DNS updates. The script will only perform updates when connected to the Internet using the selected network profile. -> indicates the currently active network profile.

   #    Network Profile
   ---  ---------------
   1    Local Area Connection* 10
   2    Network 2
   3    NetGuest
-> 4    stablewifi
   5    wlan 2

Select a network profile (1-5, Enter=4):
```

The `->` indicator points at the computer's current active network profile. To select this network, simply press `Enter` without entering a number. DNS-O-Matic updates will only occur if the computer is connected to the Internet using the network profile you select.

After you have installed **DNS-O-Matic Updater**, you can easily choose a new network profile if needed. To choose a new network profile, do one of the following:

* Reinstall the application and choose the **Update network profile** option on the **Select Additional Tasks** wizard page
* If you elected to create Start menu shortcuts, open the **Select DNS-O-Matic Profile** shortcut in the Windows Start menu

## Changing the DNS-O-Matic Credentials

When you first install **DNS-O-Matic Updater**, it prompts for your DNS-O-Matic credentials (i.e., your DNS-O-Matic username and password). If you change your password or DNS-O-Matic account, you can do one of the following to update your credentials:

* Reinstall the application and choose the **Update credentials** option on the **Select Additional Tasks** wizard page
* If you elected to create Start menu shortcuts, open the **Update DNS-O-Matic Credentials** shortcut in the Windows Start menu

## Uninstallation

You can uninstall **DNS-O-Matic Updater** from the standard Windows application list. The uninstaller will ask if it should remove all configuration and log files. If you intend to reinstall the application, you can answer "no" (in this case, you will not need to select a network profile and re-enter credentials). If you answer "yes" to this question, you will need to select a network profile and enter credentials again if you decide to reinstall.

## Automatic DNS-O-Matic Updates using the Windows Task Scheduler

When you install, the **Select Additional Tasks** wizard page gives the option to create a scheduled task to automatically perform DNS-O-Matic updates every 5 minutes. The task runs using the `LOCAL SERVICE` account, so it doesn't require a password.

To view the results of the scheduled task execution, navigate to the installation folder (e.g., `C:\Program Files\DNS-O-Matic Updater`) and view the content of the `DNSOMaticUpdater.log` file. Here's an example of the log file content:

```
**********************
Windows PowerShell transcript start
Start time: 20241105074202
Username: NT AUTHORITY\LOCAL SERVICE
RunAs User: NT AUTHORITY\LOCAL SERVICE
Configuration Name:
Machine: COMPUTER (Microsoft Windows NT 10.0.22631.0)
Host Application: C:\WINDOWS\system32\WindowsPowerShell\v1.0\PowerShell.exe -NoProfile -NonInteractive -Command & "C:\Program Files\DNS-O-Matic Updater\DNSOMaticUpdater.ps1" -Update -Log
Process ID: 20572
PSVersion: 5.1.22621.4249
PSEdition: Desktop
PSCompatibleVersions: 1.0, 2.0, 3.0, 4.0, 5.0, 5.1.22621.4249
BuildVersion: 10.0.22621.4249
CLRVersion: 4.0.30319.42000
WSManStackVersion: 3.0
PSRemotingProtocolVersion: 2.3
SerializationVersion: 1.1.0.1
**********************
Transcript started, output file is C:\Program Files\DNS-O-Matic Updater\DNSOMaticUpdater.log
good 1.2.3.4
**********************
Windows PowerShell transcript end
End time: 20241105074202
**********************
```

In the log, the script's output is the line immediately following the line that states "Transcript started"--in this case:

    good 1.2.3.4

That is, the DNS-O-Matic service successfully registered an update ("good") with the external IP address (`1.2.3.4` in this example).

You will also see:

    Skipping update: External IP address still '1.2.3.4'

The PowerShell script records the IP address of the last update and skips the update request if the external IP address hasn't changed.

## Technical Details

Behind the scenes, **DNS-O-Matic Updater** is a Windows PowerShell script, `DNSOMaticUpdater.ps1`. For more information about the script, pass the script's name as a parameter to **Get-Help** on the PowerShell command line; for example:

    PS C:\> Get-Help "C:\Program Files\DNS-O-Matic Updater\DNSOMaticUpdater.ps1"
