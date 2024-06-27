param (
    [string]$GitRepoDir,
    [string]$ChangesDir
)

function Merge-TextFiles {
    param (
        [string]$File1,
        [string]$File2,
        [string]$OutputFile
    )

    $Content1 = Get-Content -Path $File1
    $Content2 = Get-Content -Path $File2

    $Conflicts = $false
    $MergedContent = [System.Collections.ArrayList]::new()

    # Determine the longer content length
    $maxLength = [math]::Max($Content1.Count, $Content2.Count)

    for ($i = 0; $i -lt $maxLength; $i++) {
        $line1 = if ($i -lt $Content1.Count) { $Content1[$i] } else { $null }
        $line2 = if ($i -lt $Content2.Count) { $Content2[$i] } else { $null }

        if ($line1 -ne $line2) {
            if ($line2 -eq $null) {
                # Line was deleted in the changes
                continue
            } elseif ($line1 -eq $null) {
                # Line was added in the changes
                $MergedContent.Add($line2) > $null
            } else {
                # Conflict detected
                Write-Host "Conflict detected at line $i in $File1 and $File2" -ForegroundColor Yellow
                $Conflicts = $true
                break
            }
        } else {
            $MergedContent.Add($line1) > $null
        }
    }

    if (-not $Conflicts) {
        $MergedContent | Out-File -FilePath $OutputFile -Encoding utf8
    }

    return -not $Conflicts
}

function CopyNewAndChangedFiles {
    param (
        [string]$SourceDir,
        [string]$TargetDir
    )

    $Files = Get-ChildItem -Path $SourceDir -Recurse

    foreach ($File in $Files) {
        $RelativePath = $File.FullName.Substring($SourceDir.Length + 1)
        $TargetPath = Join-Path -Path $TargetDir -ChildPath $RelativePath

        if (Test-Path -Path $TargetPath) {
            # File exists in both directories, try to merge if it's a text file
            if ($File.Extension -in @(".txt", ".json", ".xml", ".yml")) {
                $mergeSuccessful = Merge-TextFiles -File1 $TargetPath -File2 $File.FullName -OutputFile $TargetPath
                if (-not $mergeSuccessful) {
                    Write-Host "Merge failed for $RelativePath. File has been ignored." -ForegroundColor Red
                }
            } else {
                # If not a text file, copy the one from the source or handle as needed
                Copy-Item -Path $File.FullName -Destination $TargetPath -Force
            }
        } else {
            # File only exists in the source, copy it
            Copy-Item -Path $File.FullName -Destination $TargetPath -Force
        }
    }
}

function RemoveDeletedFiles {
    param (
        [string]$SourceDir,
        [string]$TargetDir
    )

    $TargetFiles = Get-ChildItem -Path $TargetDir -Recurse

    foreach ($TargetFile in $TargetFiles) {
        $RelativePath = $TargetFile.FullName.Substring($TargetDir.Length + 1)
        $SourcePath = Join-Path -Path $SourceDir -ChildPath $RelativePath

        if (-not (Test-Path -Path $SourcePath)) {
            Remove-Item -Path $TargetFile.FullName -Force
            Write-Host "Deleted $RelativePath from $TargetDir" -ForegroundColor Green
        }
    }
}

# Remove deleted files
RemoveDeletedFiles -SourceDir $ChangesDir -TargetDir $GitRepoDir

# Perform the copy and merge
CopyNewAndChangedFiles -SourceDir $ChangesDir -TargetDir $GitRepoDir

Write-Host "Files from $ChangesDir have been integrated into the Git repository at $GitRepoDir"
