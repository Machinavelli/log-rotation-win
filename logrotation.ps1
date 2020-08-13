<#   
.SYNOPSIS   
Script to delete or list old files in a folder
    
.DESCRIPTION 
Script to delete files older than x-days. The script is built to be used as a scheduled task
.PARAMETER LogsPath 
The path that will be scanned files.

.PARAMETER FileAgeDays
Filter for age of file, entered in days. Use -1 for all files to be removed.

.PARAMETER IncludeFileExtension
Specifies an extension or multiple extensions in quotes, separated by commas. The extensions will be included in the deletion, all other extensions will implicitly be excluded. Asterisk can be used as a wildcard.

.PARAMETER ListOnly
List matched files. Does not remove or modify files.

.PARAMETER NewExtension
Move matched file's content into a file suffixed with NewExtension value. Creates the new file, or appends if it exists 

.PARAMETER CreateTime
Deletes files based on CreationTime, the default behaviour of the script is to delete based on LastWriteTime.

#>

param(
    [string]   $LogsPath,
	[decimal]  $FileAgeDays,
    [string[]] $IncludeFileExtension,
    [switch]   $ListOnly,
    [string]   $NewExtension,
	[switch]   $CreateTime,
    [switch]   $LastAccessTime
)

# Check if correct parameters are used
if (-not $LogsPath) {
    Write-Error('Please specify the -LogsPath required parameter')
    exit
}
if (-not $FileAgeDays) {
    Write-Error('Please specify the -FileAgeDays required parameter')
    exit
}
if ($NewExtension -and (($NewExtension -eq '') -or (-not $NewExtension))) {
    Write-Error('Please specify -NewExtension to which files should be renamed')
    exit
}

if ($NewExtension -and $IncludeFileExtension) {
    for ($i=0;$i -lt $IncludeFileExtension.Count;$i++) {
        if ($IncludeFileExtension[$i] -eq $NewExtension) {
            Write-Error('Same new file extension specified as a file extension to be matched. This would lead to appending the file to itself, if matched.')
            exit
        }
    }
}

if ($ListOnly) {
    Write-Output("***List files only, no files will be modified***")
}

$Startdate = Get-Date
$DeleteBeforeDate = $Startdate.AddDays(-$FileAgeDays)

# Define the properties to be filtered on 
$SelectProperty = @{'Property'='Fullname','Length','PSIsContainer'}
if ($CreateTime) {
	$SelectProperty.Property += 'CreationTime'
} elseif ($LastAccessTime) {
    $SelectProperty.Property += 'LastAccessTime'
} else {
	$SelectProperty.Property += 'LastWriteTime'
}

if ($IncludeFileExtension) {
    $SelectProperty.Property += 'Extension'
}

# Get the complete list of files and save to array
Write-Output "`nRetrieving list of files and folders from: $LogsPath"
$CheckError = $Error.Count
if ($LogsPath -match '\[|\]') {
    $null = New-PSDrive -Name TempDrive -PSProvider FileSystem -Root $LogsPath
    $FullArray = @(Get-ChildItem -LiteralPath TempDrive:\ -Recurse -ErrorAction SilentlyContinue -Force | Select-Object @SelectProperty)
} else {
    $FullArray = @(Get-ChildItem -LiteralPath $LogsPath -Recurse -ErrorAction SilentlyContinue -Force | Select-Object @SelectProperty)
}

# Split the complete list of items into a separate list containing only the files
$FileList   = @($FullArray | Where-Object {$_.PSIsContainer -eq $false})

# if not present, add dot in front of desired new extension
if ($NewExtension) {
    if ($NewExtension.Substring(0,1) -ne '.') {$NewExtension = ".$($NewExtension)"}
}

# keep onlz filenames matching -IncludeFileExtension
if ($IncludeFileExtension) {
    for ($j=0;$j -lt $IncludeFileExtension.Count;$j++) {
        # If no dot is present the dot will be added to the front of the string
        if ($IncludeFileExtension[$j].Substring(0,1) -ne '.') {$IncludeFileExtension[$j] = ".$($IncludeFileExtension[$j])"}
        [array]$NewFileList += @($FileList | Where-Object {$_.Extension -like $IncludeFileExtension[$j]})
    }
    $FileList = $NewFileList
}


# note errors on inaccessible files
$CheckError = $Error.Count - $CheckError
if ($CheckError -gt 0) {
	for ($j=0;$j -lt $CheckError;$j++) {
        $TempErrorVar = "$($Error[$j].ToString()) ::: $($Error[$j].TargetObject)"
        Write-Output("FAILED ACCESS`t$TempErrorVar")
    }
}


# If the -CreateTime switch has been used the script looks for file creation time rather than
# file modified/lastwrite time
if ($CreateTime) {
	$FileList = @($FileList | Where-Object {$_.CreationTime -le $DeleteBeforeDate})
} elseif ($LastAccessTime) {
    $FileList = @($FileList | Where-Object {$_.LastAccessTime -le $DeleteBeforeDate})
} else {
    $FileList = @($FileList | Where-Object {$_.LastWriteTime -le $DeleteBeforeDate})
}

Write-Output "`nAll Files`t: $($FullArray.Count)`nOld Files`t: $($FileList.Count)"


if (-not $ListOnly) {
    Write-Output "`nRemoving files..."
} else {
    Write-Output "`nListing files..."
}

# Delete Files, Rename files, append files
for ($j=0;$j -lt $FileList.Count;$j++) {
	$tempfile = $FileList[$j].FullName
	
	if (-not $?) {
		$TempErrorVar = "$($Error[0].ToString()) ::: $($Error[0].targetobject)"
		Write-Output("FAILED FILE $TempErrorVar")
	} else {
        $msg = "Matched file $tempfile "
        if($CreateTime) {
            $msg += "created at $($FileList[$j].CreationTime.ToString('yyyy-MM-dd'))"
        } elseif ($LastAccessTime) {
            $msg += "last accessed at $($FileList[$j].LastAccessTime.ToString('yyyy-MM-dd'))"
        } else {
            $msg += "last written $($FileList[$j].LastWriteTime.ToString('yyyy-MM-dd'))"
        }
        Write-Output($msg + "`tsize: $([int]($FileList[$j].length/1KB)) kB")
	}

    if ($NewExtension) {
        if ($IncludeFileExtension) {
            $NewFile = [Regex]::Replace($TempFile,$IncludeFileExtension, $NewExtension)
        } else {
            $NewFile = [io.path]::ChangeExtension($Tempfile,$NewExtension)
        }

        if (-not (Test-Path $NewFile)) {
            
            if (-not $ListOnly) {
                Write-Output("Change file extension $Tempfile to $NewFile")
                Move-Item -Path $TempFile -Destination $NewFile
            } else {
                Write-Output("Would rename file $Tempfile to $NewFile")
            }
        } elseif (Test-Path $Tempfile) {
            if (-not $ListOnly) {
                Write-Output("Append file $Tempfile to $NewFile")
                $TempFile | Add-Content -LiteralPath $NewFile
            } else {
                Write-Output("File exists $NewFile")
                Write-Output("Would append $Tempfile to $NewFile")
            }
        }
    }
    if (-not $ListOnly) {
        if (Test-Path $NewFile) {
            Remove-Item -LiteralPath $Tempfile -Force -ErrorAction SilentlyContinue
            Write-Output("Deleted file $Tempfile")
        } else {
            Write-Output("File already gone $Tempfile")
        }
            
    } else {
       Write-Output("Would have deleted $Tempfile") 
    }
    Write-Output("")
}
