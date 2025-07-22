aws lambda list-functions --profile $profiles | ConvertFrom-Json | Select-Object -ExpandProperty Functions | ForEach-Object {
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
} | Export-Csv -Path "lambda-functions.csv" -NoTypeInformation -Encoding UTF8
