
# Get the number of AWS profiles
$PROFS = (Select-String -Path "$HOME\.aws\config" -Pattern "profile ").length
$CON = 0

# Initialize array to store all lambda functions
$AllLambdaFunctions = @()

Write-Output "Processing $PROFS AWS profiles..."

# Loop through each profile
while ( $CON -lt $PROFS ) {
    $PROFILES = (Select-String -Path "$HOME\.aws\config" -Pattern "profile ")[$CON] |  ForEach-Object{([string]$_).Split("[")[1]} | ForEach-Object{([string]$_).Split("]")[0]} | ForEach-Object{([string]$_).Split(" ")[1]}
    
    Write-Output "Processing profile: $PROFILES"
    
    # Get lambda functions for current profile and add to combined array
    try {
        $LambdaFunctions = aws lambda list-functions --profile $PROFILES | ConvertFrom-Json | Select-Object -ExpandProperty Functions | ForEach-Object {
            [PSCustomObject]@{
                Account = $PROFILES
                FunctionName = $_.FunctionName
                FunctionArn = $_.FunctionArn
                FunctionVersion = $_.FunctionVersion
                FunctionMemorySize = $_.MemorySize
                FunctionTimeout = $_.Timeout
                FunctionRuntime = $_.Runtime
                FunctionCodeSize = $_.CodeSize
                FunctionLastModified = $_.LastModified
                FunctionStatus = $_.Status
            }
        }
        
        # Add current profile's functions to the combined array
        $AllLambdaFunctions += $LambdaFunctions
        
        Write-Output "Added $($LambdaFunctions.Count) functions from profile $PROFILES"
    }
    catch {
        Write-Warning "Failed to retrieve Lambda functions for profile $PROFILES : $($_.Exception.Message)"
    }
    
    $CON = $CON + 1
}

# Export all lambda functions to a single CSV file
$OutputFile = "all-lambda-functions.csv"
$AllLambdaFunctions | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Output "Export complete! Total $($AllLambdaFunctions.Count) Lambda functions exported to $OutputFile" 
