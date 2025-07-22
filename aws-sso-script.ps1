$PROFS = (Select-String -Path "$HOME\.aws\config" -Pattern "profile ").length
$CON=0
while ( $CON -lt $PROFS ) {
    $PROFILES = (Select-String -Path "$HOME\.aws\config" -Pattern "profile ")[$CON] |  ForEach-Object{([string]$_).Split("[")[1]} | ForEach-Object{([string]$_).Split("]")[0]} | ForEach-Object{([string]$_).Split(" ")[1]}
               Write-Output $PROFILES
    #
    aws lambda list-functions --profile $PROFILES | ConvertFrom-Json | Select-Object -ExpandProperty Functions | ForEach-Object {
        [PSCustomObject]@{
            Account = $profiles
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
    } | Export-Csv -Path "$PROFILES-lambda-functions.csv" -NoTypeInformation -Encoding UTF8
    #
    $CON = $CON + 1
}