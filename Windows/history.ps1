# history.ps1
#   List all commands from the persistent history
#   If search terms are provided, only return commands containing ALL search terms (case-insensitive)

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$SearchTerms
)

$historyPath = (Get-PSReadLineOption).HistorySavePath
$history = Get-Content $historyPath

if ($SearchTerms -and $SearchTerms.Count -gt 0) {
    # Filter history to only include lines containing ALL search terms (case-insensitive)
    $history | Where-Object {
        $line = $_
        $allTermsPresent = $true
        foreach ($term in $SearchTerms) {
            if ($line -notlike "*$term*") {
                $allTermsPresent = $false
                break
            }
        }
        $allTermsPresent
    }
} else {
    # If no search terms provided, return all history
    $history
}