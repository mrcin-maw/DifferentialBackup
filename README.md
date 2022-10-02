# DifferentialBackup
a script supporting local backup of files you are currently working on (it will not replace usage of CTRL + S!)

# How to use it?

## monitoredfolders.txt - parameters file
Just run the script - on the first run it will create the parameters file "monitoredfolders.txt" in the file path.

After setting up the configuration file (see section below), the file running in a separate process will check folders (and sub-) every set time according to the list and exclusions given in the file. Each changed file will be saved in the hidden `_backup_` folder of the level from which the snapshot was taken.
Each folder - whether it is created from the path given in the configuration file or from a subfolder found by the subfolders parameter - will have a separate set of snapshots in its `_backup_` folder.

# How To configure it?
## In the previously created file `monitoredfolders.txt`, you can set the parameters at line 0:
```73;exclude:*.raw,*.7z,*.zip,*.bak,*.old,*.lnk,*.url;subfolders:1```

(seconds between snapshots;exclude extensions; add subfolders paths level /currently implemented only one level/)

in others lines you need to add at least one folder to watch - i.e.: see config* used by me (*partially cutted)

``monitoredfolders.txt``
```
73;exclude:*.raw,*.7z,*.zip,*.bak,*.old,*.lnk,*.url;subfolders:1
P:\_G2F_GFX_
P:\_G2F_GFX_\Zorro_saludos_Atarros!_SV2022SE edition
P:\_G2F_GFX_\Druid_screen
P:\_G2F_GFX_\Arr, matey!
.
```

## Other parameters
In the code You can find variable which helps you to test the changes in the file:

``#use $testInISE = $true #to start in ISE
#use $testInISE = $false #to run in separated window``

so, if you will work with PowerShell ISE, ru it from the ISE console:

``$testInISE = $true``
after this, it will not run the script as the separated process but will continue in editor window
