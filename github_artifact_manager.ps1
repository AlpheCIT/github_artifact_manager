# GitHub Artifacts Manager - Organization and Repository Agnostic Script
function Format-FileSize {
    param([long]$bytes)
    if ($bytes -lt 1MB) {
        return "$([math]::Round($bytes / 1KB, 2)) KB"
    }
    elseif ($bytes -lt 1GB) {
        return "$([math]::Round($bytes / 1MB, 2)) MB"
    }
    else {
        return "$([math]::Round($bytes / 1GB, 2)) GB"
    }
}

# Account type selection
Write-Host "GitHub Artifacts Manager" -ForegroundColor Cyan
Write-Host "----------------------" -ForegroundColor Cyan
Write-Host "1. Organization account"
Write-Host "2. Personal account"
Write-Host "3. Enter repositories manually"
$accountType = Read-Host "Select option (1-3)"

$repos = @()

if ($accountType -eq "1") {
    $orgName = Read-Host "Enter GitHub organization name"
    Write-Host "Retrieving repositories for organization: $orgName..." -ForegroundColor Cyan
    $repos = @(gh repo list $orgName --json nameWithOwner --jq ".[].nameWithOwner" | ForEach-Object { $_ })
}
elseif ($accountType -eq "2") {
    $username = Read-Host "Enter GitHub username"
    Write-Host "Retrieving repositories for user: $username..." -ForegroundColor Cyan
    $repos = @(gh repo list $username --json nameWithOwner --jq ".[].nameWithOwner" | ForEach-Object { $_ })
}
else {
    Write-Host "Enter repositories in the format 'owner/repo' (one per line, empty line to finish):"
    do {
        $repoInput = Read-Host
        if (-not [string]::IsNullOrWhiteSpace($repoInput)) {
            $repos += $repoInput.Trim()
        }
    } while (-not [string]::IsNullOrWhiteSpace($repoInput))
}

if ($repos.Count -eq 0) {
    Write-Host "No repositories found or entered" -ForegroundColor Red
    exit
}

# Display numbered list of repositories
Write-Host "`nAvailable repositories:" -ForegroundColor Cyan
for ($i = 0; $i -lt $repos.Count; $i++) {
    Write-Host "  $($i+1). $($repos[$i])"
}

# Allow user to select repositories
Write-Host "`nSelect repositories (comma-separated numbers, or 'all' for all repos):"
$selection = Read-Host "Selection"

$selectedRepos = @()
if ($selection -eq "all") {
    $selectedRepos = $repos
}
else {
    $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
    foreach ($index in $indices) {
        if ($index -ge 0 -and $index -lt $repos.Count) {
            $selectedRepos += $repos[$index]
        }
    }
}

if ($selectedRepos.Count -eq 0) {
    Write-Host "No valid repositories selected" -ForegroundColor Red
    exit
}

Write-Host "`nSelected repositories:" -ForegroundColor Cyan
$selectedRepos | ForEach-Object { Write-Host "  - $_" }

# Date filtering options
Write-Host "`nDate filtering options:" -ForegroundColor Cyan
Write-Host "1. Show all artifacts"
Write-Host "2. Show artifacts older than a specific date"
Write-Host "3. Show artifacts within a date range"
Write-Host "4. Show artifacts older than X days"
$dateOption = Read-Host "Select an option (1-4)"

$startDate = $null
$endDate = $null
$dateFilter = ""

if ($dateOption -eq "2") {
    $dateInput = Read-Host "Show artifacts older than (YYYY-MM-DD)"
    $startDate = [DateTime]::MinValue
    $endDate = [DateTime]::ParseExact($dateInput, "yyyy-MM-dd", $null)
    $dateFilter = "before $($endDate.ToString('yyyy-MM-dd'))"
}
elseif ($dateOption -eq "3") {
    $startDateInput = Read-Host "Start date (YYYY-MM-DD)"
    $endDateInput = Read-Host "End date (YYYY-MM-DD)"
    $startDate = [DateTime]::ParseExact($startDateInput, "yyyy-MM-dd", $null)
    $endDate = [DateTime]::ParseExact($endDateInput, "yyyy-MM-dd", $null).AddDays(1).AddSeconds(-1)
    $dateFilter = "between $($startDate.ToString('yyyy-MM-dd')) and $($endDate.ToString('yyyy-MM-dd'))"
}
elseif ($dateOption -eq "4") {
    $daysAgo = [int](Read-Host "Show artifacts older than how many days?")
    $startDate = [DateTime]::MinValue
    $endDate = [DateTime]::Now.AddDays(-$daysAgo)
    $dateFilter = "older than $daysAgo days (before $($endDate.ToString('yyyy-MM-dd')))"
}

# Process each selected repository
$allArtifacts = @()

foreach ($repo in $selectedRepos) {
    Write-Host "`nFetching artifacts for $repo..." -ForegroundColor Cyan
    
    try {
        # Get artifacts with their details
        $artifactsJson = gh api "repos/$repo/actions/artifacts" --paginate
        
        # Extract total count using regex
        $totalCount = if ($artifactsJson -match '"total_count":\s*(\d+)') { [int]$matches[1] } else { 0 }
        
        # Use a simpler regex pattern that's more robust
        $pattern = '"id":(\d+),"node_id":"MDg6QXJ0aWZhY3Q[^"]*","name":"([^"]*)","size_in_bytes":(\d+)[^"]*"created_at":"([^"]*)"'
        $matches = [regex]::Matches($artifactsJson, $pattern)
        
        Write-Host "  Found $totalCount artifacts from API, extracted $($matches.Count) with regex" -ForegroundColor Yellow
        
        $repoArtifacts = @()
        
        foreach ($match in $matches) {
            $id = $match.Groups[1].Value
            $name = $match.Groups[2].Value
            $sizeBytes = [long]$match.Groups[3].Value
            $createdAtStr = $match.Groups[4].Value
            
            try {
                $createdAt = [DateTime]::Parse($createdAtStr)
                
                $repoArtifacts += [PSCustomObject]@{
                    Repository = $repo
                    Id = $id
                    Name = $name
                    "Size (MB)" = [math]::Round($sizeBytes / 1MB, 2)
                    "Size (Bytes)" = $sizeBytes
                    "Created" = $createdAt
                    "Created (Format)" = $createdAt.ToString('yyyy-MM-dd HH:mm:ss')
                }
            } catch {
                Write-Host "  Error parsing date from $createdAtStr" -ForegroundColor Red
            }
        }
        
        # If the regex didn't work well, try an alternative approach
        if ($repoArtifacts.Count -eq 0 -and $totalCount -gt 0) {
            Write-Host "  Trying alternative pattern..." -ForegroundColor Yellow
            $pattern = '"id":(\d+)[^}]*"name":"([^"]*)"[^}]*"size_in_bytes":(\d+)[^}]*"created_at":"([^"]*)"'
            $matches = [regex]::Matches($artifactsJson, $pattern)
            
            foreach ($match in $matches) {
                $id = $match.Groups[1].Value
                $name = $match.Groups[2].Value
                $sizeBytes = [long]$match.Groups[3].Value
                $createdAtStr = $match.Groups[4].Value
                
                try {
                    $createdAt = [DateTime]::Parse($createdAtStr)
                    
                    $repoArtifacts += [PSCustomObject]@{
                        Repository = $repo
                        Id = $id
                        Name = $name
                        "Size (MB)" = [math]::Round($sizeBytes / 1MB, 2)
                        "Size (Bytes)" = $sizeBytes
                        "Created" = $createdAt
                        "Created (Format)" = $createdAt.ToString('yyyy-MM-dd HH:mm:ss')
                    }
                } catch {
                    Write-Host "  Error parsing date from $createdAtStr" -ForegroundColor Red
                }
            }
        }
        
        # Filter artifacts by date if option 2, 3, or 4 was selected
        if ($dateOption -eq "2" -or $dateOption -eq "3" -or $dateOption -eq "4") {
            $repoArtifacts = $repoArtifacts | Where-Object { 
                $_.Created -ge $startDate -and $_.Created -le $endDate 
            }
        }
        
        $allArtifacts += $repoArtifacts
        
        Write-Host "  Successfully processed $($repoArtifacts.Count) artifacts" -ForegroundColor Green
    }
    catch {
        Write-Host "  Error retrieving artifacts: $_" -ForegroundColor Red
    }
}

# Sort and display the artifacts
if ($allArtifacts.Count -gt 0) {
    Write-Host "`nArtifacts $dateFilter (sorted by date):" -ForegroundColor Cyan
    $allArtifacts | Sort-Object -Property Created -Descending | Format-Table Repository, Id, Name, "Size (MB)", "Created (Format)" -AutoSize
    
    # Calculate and display summary
    $totalSize = ($allArtifacts | Measure-Object -Property "Size (Bytes)" -Sum).Sum
    $repoSummary = $allArtifacts | Group-Object -Property Repository | ForEach-Object {
        $repoSize = ($_.Group | Measure-Object -Property "Size (Bytes)" -Sum).Sum
        [PSCustomObject]@{
            Repository = $_.Name
            "Artifact Count" = $_.Count
            "Total Size" = Format-FileSize -bytes $repoSize
            "Size (Bytes)" = $repoSize
        }
    }
    
    Write-Host "`nRepository Summary:" -ForegroundColor Cyan
    $repoSummary | Sort-Object -Property "Size (Bytes)" -Descending | Format-Table Repository, "Artifact Count", "Total Size" -AutoSize
    
    Write-Host "Overall Total: $($allArtifacts.Count) artifacts, $(Format-FileSize -bytes $totalSize)" -ForegroundColor Green
    
    # Prompt for CSV export path to avoid file access conflict
    $exportOption = Read-Host "`nExport artifact list to CSV? (y/n)"
    if ($exportOption -eq "y") {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $defaultPath = "github_artifacts_$timestamp.csv"
        $exportPath = Read-Host "Enter export file path or press Enter for default [$defaultPath]"
        
        if ([string]::IsNullOrWhiteSpace($exportPath)) {
            $exportPath = $defaultPath
        }
        
        try {
            $allArtifacts | Export-Csv -Path $exportPath -NoTypeInformation
            Write-Host "Data exported to $exportPath" -ForegroundColor Green
        } catch {
            Write-Host "Error exporting data: $_" -ForegroundColor Red
            $retryPath = "$([System.IO.Path]::GetFileNameWithoutExtension($exportPath))_retry$([System.IO.Path]::GetExtension($exportPath))"
            $retry = Read-Host "Would you like to retry with filename $retryPath? (y/n)"
            
            if ($retry -eq "y") {
                try {
                    $allArtifacts | Export-Csv -Path $retryPath -NoTypeInformation
                    Write-Host "Data exported to $retryPath" -ForegroundColor Green
                } catch {
                    Write-Host "Export failed again. Please check file permissions and try again later." -ForegroundColor Red
                }
            }
        }
    }
    
    # Ask if user wants to delete artifacts
    $deleteOption = Read-Host "`nWould you like to delete these artifacts? (y/n)"
    if ($deleteOption -eq "y") {
        $deleteConfirm = Read-Host "Are you sure you want to delete $($allArtifacts.Count) artifacts? This cannot be undone. (y/n)"
        
        if ($deleteConfirm -eq "y") {
            $counter = 0
            $successCount = 0
            $errorCount = 0
            
            foreach ($artifact in $allArtifacts) {
                $counter++
                Write-Host "Deleting artifact $counter of $($allArtifacts.Count) (Repo: $($artifact.Repository), ID: $($artifact.Id), Created: $($artifact.'Created (Format)'))..." -NoNewline
                
                try {
                    $result = gh api "repos/$($artifact.Repository)/actions/artifacts/$($artifact.Id)" -X DELETE 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Success" -ForegroundColor Green
                        $successCount++
                    } else {
                        Write-Host "Failed: $result" -ForegroundColor Red
                        $errorCount++
                    }
                } catch {
                    Write-Host "Error: $_" -ForegroundColor Red
                    $errorCount++
                }
                
                # Small delay to avoid rate limiting
                Start-Sleep -Milliseconds 200
            }
            
            Write-Host "`nDeletion completed!" -ForegroundColor Cyan
            Write-Host "Successfully deleted: $successCount | Errors: $errorCount" -ForegroundColor Green
        } else {
            Write-Host "Deletion cancelled" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "`nNo artifacts found matching criteria" -ForegroundColor Yellow
}