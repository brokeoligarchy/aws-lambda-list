# Get the number of AWS profiles
$PROFS = (Select-String -Path "$HOME\.aws\config" -Pattern "profile ").length
$CON = 0

# Initialize array to store all lambda functions
$AllLambdaFunctions = @()

# Calculate date range for last month
$EndDate = (Get-Date).ToString("yyyy-MM-01")
$StartDate = (Get-Date).AddMonths(-1).ToString("yyyy-MM-01")

Write-Output "Processing $PROFS AWS profiles..."
Write-Output "Cost data period: $StartDate to $EndDate"

# Function to get Lambda cost from Cost Explorer
function Get-LambdaCost {
    param(
        [string]$ProfileName,
        [string]$FunctionName,
        [string]$StartDate,
        [string]$EndDate
    )
    
    try {
        # Try to get cost by function name tag first
        $CostQuery = @{
            TimePeriod = @{
                Start = $StartDate
                End = $EndDate
            }
            Granularity = "MONTHLY"
            Metrics = @("AmortizedCost")
            GroupBy = @(
                @{
                    Type = "DIMENSION"
                    Key = "SERVICE"
                }
            )
            Filter = @{
                And = @(
                    @{
                        Dimensions = @{
                            Key = "SERVICE"
                            Values = @("AWS Lambda")
                        }
                    },
                    @{
                        Tags = @{
                            Key = "Name"
                            Values = @($FunctionName)
                        }
                    }
                )
            }
        } | ConvertTo-Json -Depth 10

        $CostResult = aws ce get-cost-and-usage --cli-input-json $CostQuery --profile $ProfileName 2>$null | ConvertFrom-Json
        
        if ($CostResult -and $CostResult.ResultsByTime -and $CostResult.ResultsByTime[0].Groups) {
            $Cost = $CostResult.ResultsByTime[0].Groups[0].Metrics.AmortizedCost.Amount
            return [math]::Round([decimal]$Cost, 2)
        }

        # If no cost found by Name tag, try alternative approach - get all Lambda costs and estimate
        $AllLambdaCostQuery = @{
            TimePeriod = @{
                Start = $StartDate
                End = $EndDate
            }
            Granularity = "MONTHLY"
            Metrics = @("AmortizedCost")
            Filter = @{
                Dimensions = @{
                    Key = "SERVICE"
                    Values = @("AWS Lambda")
                }
            }
        } | ConvertTo-Json -Depth 10

        $AllLambdaResult = aws ce get-cost-and-usage --cli-input-json $AllLambdaCostQuery --profile $ProfileName 2>$null | ConvertFrom-Json
        
        if ($AllLambdaResult -and $AllLambdaResult.ResultsByTime -and $AllLambdaResult.ResultsByTime[0].Total) {
            $TotalCost = $AllLambdaResult.ResultsByTime[0].Total.AmortizedCost.Amount
            # Return a note that this is total Lambda cost for the account (cannot be attributed to specific function)
            return "Account Total: $([math]::Round([decimal]$TotalCost, 2))"
        }

        return "N/A"
    }
    catch {
        Write-Warning "Error getting cost for function $FunctionName in profile $ProfileName : $($_.Exception.Message)"
        return "Error"
    }
}

# Loop through each profile
while ( $CON -lt $PROFS ) {
    $PROFILES = (Select-String -Path "$HOME\.aws\config" -Pattern "profile ")[$CON] |  ForEach-Object{([string]$_).Split("[")[1]} | ForEach-Object{([string]$_).Split("]")[0]} | ForEach-Object{([string]$_).Split(" ")[1]}
    
    Write-Output "Processing profile: $PROFILES"
    
    # Get lambda functions for current profile and add to combined array
    try {
        $LambdaFunctions = aws lambda list-functions --profile $PROFILES | ConvertFrom-Json | Select-Object -ExpandProperty Functions | ForEach-Object {
            Write-Output "  Getting cost data for function: $($_.FunctionName)"
            
            # Get cost information for this function
            $Cost = Get-LambdaCost -ProfileName $PROFILES -FunctionName $_.FunctionName -StartDate $StartDate -EndDate $EndDate
            
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
                AmortizedCostLastMonth = $Cost
                CostPeriod = "$StartDate to $EndDate"
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
$OutputFile = "all-lambda-functions-with-costs.csv"
$AllLambdaFunctions | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Output "Export complete! Total $($AllLambdaFunctions.Count) Lambda functions with cost data exported to $OutputFile" 