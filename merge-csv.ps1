param(
    [string]$InputPath = ".",
    [string]$OutputFile = "merged-lambda-functions.csv",
    [string]$FilePattern = "*lambda-functions*.csv"
)

Write-Host "Merging CSV files..." -ForegroundColor Green
Write-Host "Input Path: $InputPath" -ForegroundColor Yellow
Write-Host "File Pattern: $FilePattern" -ForegroundColor Yellow
Write-Host "Output File: $OutputFile" -ForegroundColor Yellow

# Get all CSV files matching the pattern
$csvFiles = Get-ChildItem -Path $InputPath -Filter $FilePattern -File

if ($csvFiles.Count -eq 0) {
    Write-Host "No CSV files found matching pattern '$FilePattern' in '$InputPath'" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($csvFiles.Count) CSV files:" -ForegroundColor Green
$csvFiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Cyan }

# Initialize an array to hold all data
$allData = @()

# Process each CSV file
foreach ($file in $csvFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Yellow
    
    try {
        $data = Import-Csv -Path $file.FullName
        
        if ($data.Count -gt 0) {
            $allData += $data
            Write-Host "  Added $($data.Count) records" -ForegroundColor Green
        } else {
            Write-Host "  No data found in file" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  Error reading file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Export merged data to new CSV file
if ($allData.Count -gt 0) {
    $allData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    Write-Host "Successfully merged $($allData.Count) records into '$OutputFile'" -ForegroundColor Green
    
    # Display summary by account (if Account column exists)
    if ($allData[0].PSObject.Properties.Name -contains "Account") {
        Write-Host "`nSummary by Account:" -ForegroundColor Cyan
        $allData | Group-Object Account | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count) functions" -ForegroundColor White
        }
    }
} else {
    Write-Host "No data to merge!" -ForegroundColor Red
}

Write-Host "`nMerge completed!" -ForegroundColor Green 