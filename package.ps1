$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $projectRoot 'generate-previews.ps1')
$outputDirectory = Join-Path $projectRoot 'dist'
$outputFile = Join-Path $outputDirectory 'night-clock-roku.zip'

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
if (Test-Path -LiteralPath $outputFile) {
    Remove-Item -LiteralPath $outputFile
}

$items = @(
    (Join-Path $projectRoot 'manifest'),
    (Join-Path $projectRoot 'source'),
    (Join-Path $projectRoot 'components'),
    (Join-Path $projectRoot 'images')
)

Compress-Archive -Path $items -DestinationPath $outputFile -CompressionLevel Optimal
Write-Host "Created $outputFile"
