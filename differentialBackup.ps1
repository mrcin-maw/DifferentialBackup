using namespace System.Collections
#use $testInISE = $true #to start in ISE
#use $testInISE = $false #to run in separated window

If ($psISE -and ($testInISE -ne $true)) {
    start-process powershell -ArgumentList ('-noexit -File "'+$script:MyInvocation.MyCommand.Path+'"')
    return
}

cls
cd $PSScriptRoot

<#
I. Manifest:
1. Monitor folders mentioned in monitoredfolders.txt
2. compare (one level deep) with backuped version in _backup_ folder
3. add new copy marked with "_@[YYYYmmdd]#HHMM.{original extension}" to the _backup_ folder
#>

#parameters
[int] $defaultPauseBetweenIter_seconds = 30
[int] $pauseBetweenIter_seconds = $defaultBetweenTime_seconds
[ArrayList] $exludefiletypes = @() #no exclusions at start
[int] $includeSubs = 0 #default: only paths from folderslist
#
[psobject] $list_backupedobjects = @{
        folders = New-Object ArrayList #indexing object
        _foldername_ = New-Object psobject -Property @{
                                    filefolder = "" 
                                    files = @()
                                    backupfolder = ""
                                    dig_in = 0
                                }
    }
#
# [psobject] $backupedobject_ = @{}
# [string] $monitoredfolder_ = ""
# [string] $monitoredfile_ = ""
# [psobject] $monitoredleaf_ = @{}
# [string] $monitoredfileTimeStamp_ = ""
# [string] $backupedfile_ = ""
# [psobject] $backupedleaf_ = ""
# [string] $backupedfileTimeStamp_ = ""
#
[string] $file_monitoredfolders = "$PSScriptRoot\monitoredfolders.txt"
[string[]] $list_monitoredfolders = ,@(".")
[string] $foldersListTimeStamp = ""
#
[string] $backupfoldername = "_backup_"

#
function serializeFolderName ( [string] $foldername)
{
    [string] $serializedfoldername_ = $foldername.Replace(' ','_')
    $serializedfoldername_ = $serializedfoldername_.Replace(',','+')
    $serializedfoldername_ = $serializedfoldername_.Replace(':','!')
    $serializedfoldername_ = $serializedfoldername_.Replace('\','~')

    return $serializedfoldername_
}
function Set-Config ()
{
    [ArrayList] $parameters = @()
    [ArrayList] $otherparam = @()
    #
    Write-host " $($PSScriptRoot) Started " -ForegroundColor Black -BackgroundColor Yellow
    
    #I. In the first iteration
    #will add config file if not exists with own path 
    if (!(Test-Path $file_monitoredfolders))
    {
        Add-Content -Path $file_monitoredfolders -Value $list_monitoredfolders
    }
    else
    {
        #if exist, read monitored folders list
        ([ref] $list_monitoredfolders).Value = Get-Content -LiteralPath $file_monitoredfolders
    }

    #read parameters time from first(0) line of the config file
    #will split (semicolon) for different parameters
    #if the first element is a number it will continue with other parameters
    $parameters = $list_monitoredfolders[0] -split ";"
    if ([int]::TryParse($parameters[0],[ref]$pauseBetweenIter_seconds))
    {
        #if first(0) line cosists parameters, folders list is created from array without first item (parameters) 
        ([ref] $list_monitoredfolders).Value = $list_monitoredfolders[1..([System.Math]::max(1,$list_monitoredfolders.Length-1))]
        Write-host "New pause value from config first line ($pauseBetweenIter_seconds seconds)" -ForegroundColor Gray -BackgroundColor DarkGray
        #
        #other parameters
        if ($parameters.Count -gt 1)
        {
            $parameters.RemoveAt(0)
            $parameters|
            %{
                $otherparam = $_ -split ":"
                if ($otherparam.Count -gt 1) {
                    switch ($otherparam[0]) {
                        "exclude" {
                                ([ref] $exludefiletypes).Value = $otherparam[1] -split ","
                                Write-Host "+ exclude: $exludefiletypes" -ForegroundColor Yellow
                                break
                            }
                        "subfolders" {
                                #handling other values not implemented!
                                ([ref] $includeSubs).Value = 1
                                Write-Host "+ will include subfolders for one level deep" -ForegroundColor Yellow
                                #$includeSubs = $otherparam[1]
                                break
                            }
                    }
                }
            }
        }
    }
    else
    {
        #we have to set again because tryParse returns zero if false
        ([ref] $pauseBetweenIter_seconds).Value = $defaultPauseBetweenIter_seconds
    }
    #
    Write-Host " Items counted: $($list_monitoredfolders.Length) "  -ForegroundColor Gray -BackgroundColor DarkGray
    if ($list_monitoredfolders.Length -le 1) {
        #If some prankster leaves the file empty or just with seconds on the first line"
        ([ref] $list_monitoredfolders).Value = @(".")
    }
    if ($list_monitoredfolders[0] -eq ".") {
        Write-Host "Add the folder you want to monitor to the monitored folders file!" -ForegroundColor Red
        Write-Host "Press CTRL+C to finish the script"
        pause
    }
    #saving time stamp for configuration file
    Get-ChildItem $file_monitoredfolders|
    %{
        ([ref] $foldersListTimeStamp).Value = "$($_.BaseName)_@$(Get-Date $_.LastWriteTime -format "[yyMMdd]#HHmmss")$($_.Extension)"
    }
    #Write-Host $foldersListTimeStamp
    #
    $list_backupedobjects.folders = New-Object ArrayList
    $list_monitoredfolders|
    %{
        if (Test-Path -LiteralPath $_ -PathType Container)
        {
            Set-FolderBranch ($_)
        }
        else
        {
            Write-Host " WARNING! $_ removed from iterations because not exists! " -ForegroundColor Cyan -BackgroundColor Red
        }
    }
}
function Set-FolderBranch ([string] $folder, [int] $sublevels = $includeSubs)
{
    [string] $monitoredfolder_ = ""
    [string] $backupfolder_ = "$folder\$backupfoldername"
    [System.IO.FileInfo] $folder_
    #"$folder,$backupfolder_,$folder_"
    #
    #checking the _backup_ folder location
    try {
        $folder_ = Get-Item -Path $backupfolder_ -Force -ErrorAction Stop
    } catch {
        md $backupfolder_ -Force |Out-Null
        Write-host "$backupfolder_ - created."
        $folder_ = Get-Item -Path $backupfolder_ -Force -ErrorAction Stop
    }
    if (!($folder_.Attributes -band ([System.IO.FileAttributes]::Hidden)))
    {
        $folder_.Attributes += [System.IO.FileAttributes]::Hidden
    }
    #
    #adding entry to memory object
    #removing most-known not accepted signs
    $monitoredfolder_ = serializeFolderName($folder)
    #
    #"You was looking for this: $_`r $folder `r$monitoredfolder_"
    $list_backupedobjects[$monitoredfolder_] = @{
        backupfolder = $backupfolder_
        filefolder = $_
        dig_in = $sublevels
        files = New-Object hashtable
    }
    $list_backupedobjects.folders.Add($monitoredfolder_)|Out-Null
}
function Check-ConfigModifications ()
{
    [string] $timeStamp_ = ""
    Get-ChildItem $file_monitoredfolders|
    %{
        $timeStamp_ = "$($_.BaseName)_@$(Get-Date $_.LastWriteTime -format "[yyMMdd]#HHmmss")$($_.Extension)"
    }
    if ($foldersListTimeStamp -ne $timeStamp_)
    {
        Write-Host " detected configuration file change, adding new folders " -ForegroundColor Red -BackgroundColor Cyan
        Set-Config
    }
}
function Check-Folders ([string] $folder_)
{
    #3a. read the leaf-elements from the folder
    #(new-mod:) add sub-folders /one level deep/ if allowed
    [psobject] $backupedobject_ = $list_backupedobjects[$folder_]
    Write-Host "$($backupedobject_.filefolder) : " -BackgroundColor DarkCyan
    #
    [string] $monitoredfolder_ = $backupedobject_.filefolder
    [string] $backupfolder_ = $backupedobject_.backupfolder
    #
    [psobject] $monitoredleaf_ = @{}
    [string] $monitoredfile_ = ""
    [psobject] $backupedleaf_ = ""
    [string] $backupedfile_ = ""
    [string] $backupedfileTimeStamp_ = ""
    [string] $monitoredfileTimeStamp_ = ""
    #
    Write-Host "excl: $exludefiletypes" -ForegroundColor DarkCyan
    Get-ChildItem -Path $monitoredfolder_ -Exclude $exludefiletypes|Sort-Object {$_.LastWriteTime}| 
    %{
        if (!$_.PsIsContainer)
        {
            $monitoredleaf_ = $_
            $monitoredfile_ = $_.Name
            $monitoredfileTimeStamp_ = "$($_.BaseName)_@$(Get-Date $_.LastWriteTime -format "[yyMMdd]#HHmmss")$($_.Extension)"
            #3b. save to the memory object date, size and backup name of the leaf
            $backupedfileTimeStamp_ = $backupedobject_.files[$monitoredfile_].described
            $backupedobject_.files[$monitoredfile_] = @{
                    writed = Get-Date $monitoredleaf_.LastWriteTime -format "yyyMMddHHmmss"
                    size =  $monitoredleaf_.Length
                    described = $monitoredfileTimeStamp_ 
                }
            #
            #3c. try* to copy leaf file to backup folder if was not recalled or has different time and date stamp
            if ("$backupedfileTimeStamp_" -ne "$monitoredfileTimeStamp_")
            {
                Write-Host "`t $monitoredfile_... " -NoNewline
                if ("$backupedfileTimeStamp_" -eq "") {
                    Write-Host " (not called earlier) "
                }
                $backupedfile_ = "$backupfolder_\$monitoredfile_"
                if (Test-Path $backupedfile_ -PathType Leaf) {
                    $backupleaf_ = Get-Item $backupedfile_
                    #if the previous backup without time signature exists, you'll stay here
                    $backupedfileTimeStamp_ = "$($backupleaf_.BaseName)_@$(Get-Date $backupleaf_.LastWriteTime -format "[yyMMdd]#HHmmss")$($backupleaf_.Extension)"
                    #$monitoredleaf_.FullName
                    #"monitored:`t $($monitoredleaf_.LastWriteTime) `t$($monitoredleaf_.Length) `t$monitoredfileTimeStamp_"
                    #"backuped: `t $($backupleaf_.LastWriteTime) `t$($backupleaf_.Length) `t$backupedfileTimeStamp_"
                    # * if different file (different writeTime,size) exist in the backup folder, 
                    if (($monitoredleaf_.Length -ne $backupleaf_.Length) -or ($monitoredfileTimeStamp_ -ne $backupedfileTimeStamp_))
                    {
                        #try** to add the timeStamp to the older "{BaseFileName}_@[YYYYmmdd]#HHMM.{original extension}"
                        #where date-time object comes from the LastWriteTime parameter of the backuped leaf
                        $backupedfile_ = "$backupfolder_\$backupedfileTimeStamp_"
                        # ** if the same file but with backup extension exists in the backup folder,
                        #del "the file without timeStamp"
                        if (Test-Path $backupedfile_ -PathType Leaf)
                        {
                            del $backupleaf_ -Force
                            Write-Host "`t deleting duplicated backup copy: $backupleaf_, " -ForegroundColor Red
                        } else {
                            ren $backupleaf_ $backupedfileTimeStamp_
                            Write-Host "`t ageing backup copy to: $backupedfileTimeStamp_, " -BackgroundColor DarkYellow
                        }
                        copy $monitoredleaf_.FullName $backupfolder_
                        Write-host "$monitoredfile_ - copying new version to backup." -ForegroundColor Green
                    }
                } else {
                    #file not exists - so simple
                    copy $monitoredleaf_.FullName $backupfolder_
                    Write-host " backuped: $monitoredleaf_" -BackgroundColor DarkGreen
                }
            }
        }
        elseif (($list_backupedobjects[$folder_].dig_in -gt 0) -and !($list_backupedobjects.folders).Contains( (serializeFolderName $_ ) ))
        {
            Write-host "$_ - internal folder added to review " -ForegroundColor DarkCyan
            #$($list_backupedobjects[$folder_].filefolder) `
            #$($list_backupedobjects[$folder_].dig_in)
            #if (($list_backupedobjects.folders).Contains( (serializeFolderName "$_") )) {pause}
            Set-FolderBranch $_ -sublevels ($list_backupedobjects[$folder_].dig_in - 1)
        }
    }
    Write-host " $folder_ reviewed.`n" -ForegroundColor DarkYellow
}
Set-Config

[int] $i = 0
do {
    #re-check if there were changes in configuration files
    Check-ConfigModifications
    #3. Check monitored folders one by one for files
    Write-Host "`n New iteration... $(Get-date -format "[yyyy-MM-dd @HH:mm:ss]") `n" -ForegroundColor Black -BackgroundColor DarkYellow
    if ($list_backupedobjects.folders.Count -gt 0)
    {
        for ($i = 0;$i -lt ($list_backupedobjects.folders).Count;$i++)
        {
            Check-Folders($list_backupedobjects.folders[$i])
        }
    }
    else
    {
        Write-Host " no folders for this iteration... check config file..." -ForegroundColor Red
    }
    Write-Host "...iteration finished, $pauseBetweenIter_seconds sec pause." -ForegroundColor Yellow
    Start-Sleep -Seconds $pauseBetweenIter_seconds
} while ($true)
