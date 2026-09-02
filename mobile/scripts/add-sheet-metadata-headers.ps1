# Adds SpendWise metadata column headers (AA-BA) to Daily Expenses.xlsx Sheet1 tabs.
param(
    [Parameter(Mandatory = $true)]
    [string]$XlsxPath
)

function Escape-Xml([string]$Text) {
    return $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

function Build-MetadataHeaderCells {
    $cols = @(
        'AA', 'AB', 'AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AL', 'AM', 'AN',
        'AO', 'AP', 'AQ', 'AR', 'AS', 'AT', 'AU', 'AV', 'AW', 'AX', 'AY', 'AZ', 'BA'
    )
    $headers = @(
        'Transaction ID', 'Type', 'Category', 'Gross Amount', 'Net Amount', 'Cashback',
        'Source ID', 'Source Name', 'Source Type', 'Method ID', 'Method Name',
        'App ID', 'App Name', 'Notes', 'Parent Txn ID', 'Split ID', 'Split Type',
        'Split Summary', 'Split Settled', 'Split Details (IDs)', 'My Share',
        'Group ID', 'Group Name', 'Settlement Contact ID', 'Settlement Contact Name',
        'Updated At', 'Sync Source'
    )
    if ($cols.Count -ne $headers.Count) {
        throw 'Column/header count mismatch'
    }
    $cells = for ($i = 0; $i -lt $cols.Count; $i++) {
        $text = Escape-Xml $headers[$i]
        "<c r=`"$($cols[$i])1`" s=`"15`" t=`"inlineStr`"><is><t>$text</t></is></c>"
    }
    return ($cells -join '')
}

function Update-WorksheetXml([string]$Path, [string]$HeaderBlock) {
    $xml = Get-Content -Path $Path -Raw -Encoding UTF8
    $pattern = '<c r="AA1" s="15"/>(?:<c r="[A-Z]+1" s="15"/>)*'
    if ($xml -notmatch $pattern) {
        throw "Could not find empty AA-AS header cells in $Path"
    }
    $updated = [regex]::Replace($xml, $pattern, $HeaderBlock, 1)
    if ($updated -eq $xml) {
        throw "No changes applied to $Path"
    }
    [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path $XlsxPath)) {
    throw "File not found: $XlsxPath"
}

$backup = "$XlsxPath.bak"
if (-not (Test-Path $backup)) {
    Copy-Item $XlsxPath $backup
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("spendwise-xlsx-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $work | Out-Null
$zipCopy = Join-Path $work 'book.zip'
Copy-Item $XlsxPath $zipCopy
Expand-Archive -Path $zipCopy -DestinationPath (Join-Path $work 'unzipped') -Force

$headerBlock = Build-MetadataHeaderCells
$sheetDir = Join-Path $work 'unzipped\xl\worksheets'
Update-WorksheetXml (Join-Path $sheetDir 'sheet2.xml') $headerBlock
Update-WorksheetXml (Join-Path $sheetDir 'sheet3.xml') $headerBlock

Add-Type -AssemblyName System.IO.Compression.FileSystem
$outZip = Join-Path $work 'updated.xlsx'
if (Test-Path $outZip) { Remove-Item $outZip -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    (Join-Path $work 'unzipped'),
    $outZip,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

Copy-Item $outZip $XlsxPath -Force
Remove-Item $work -Recurse -Force
Write-Output "Updated metadata headers in: $XlsxPath"
