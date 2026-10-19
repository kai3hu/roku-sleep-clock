$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$sharedRoot = Join-Path $projectRoot 'outlook-screensaver'
if (-not (Test-Path -LiteralPath (Join-Path $sharedRoot 'source/config.brs'))) {
    Copy-Item -LiteralPath (Join-Path $sharedRoot 'source/config.brs.example') -Destination (Join-Path $sharedRoot 'source/config.brs')
}
& (Join-Path $projectRoot 'generate-dashboard-assets.ps1')
$stage = Join-Path $projectRoot '.tools/dashboard-stage'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
# Staging is generated, ignored build output. Shared screensaver sources stay intact.
foreach ($directory in @('components','source','fonts','images')) {
    Copy-Item -LiteralPath (Join-Path $sharedRoot $directory) -Destination $stage -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'dashboard-app/manifest') -Destination (Join-Path $stage 'manifest') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'dashboard-app/source/main.brs') -Destination (Join-Path $stage 'source/main.brs') -Force
foreach ($name in @('menu-hd.png','menu-fhd.png')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('dashboard-app/images/'+$name)) -Destination (Join-Path $stage ('images/'+$name)) -Force
}
# Mechanically specialize the shared scene, avoiding two drifting copies of its UI.
$scene = [xml](Get-Content -LiteralPath (Join-Path $sharedRoot 'components/NightScheduleScene.xml') -Raw)
$scene.component.SetAttribute('name','SleepDashboardScene')
$scene.component.interface.field.SetAttribute('value','true')
$xmlSettings = [Xml.XmlWriterSettings]::new()
$xmlSettings.Encoding = [Text.UTF8Encoding]::new($false)
$xmlSettings.Indent = $true
$writer = [Xml.XmlWriter]::Create((Join-Path $stage 'components/SleepDashboardScene.xml'), $xmlSettings)
try {$scene.Save($writer)} finally {$writer.Dispose()}
$compiler = Join-Path $projectRoot 'node_modules/brighterscript/dist/cli.js'
if (-not (Test-Path -LiteralPath $compiler)) {$compiler = Join-Path $projectRoot '.tools/node_modules/brighterscript/dist/cli.js'}
if (-not (Test-Path -LiteralPath $compiler)) {throw 'Run npm install before building the app.'}
& node $compiler --root-dir $stage --copy-to-staging=false --create-package=false --diagnostic-level warn
if ($LASTEXITCODE -ne 0) {throw 'Dashboard compilation failed'}
$outputDirectory = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$output = Join-Path $outputDirectory 'sleep-dashboard-roku.zip'
Compress-Archive -Path @((Join-Path $stage 'manifest'),(Join-Path $stage 'source'),(Join-Path $stage 'components'),(Join-Path $stage 'fonts'),(Join-Path $stage 'images')) -DestinationPath $output -Force -CompressionLevel Optimal
Write-Host "Created $output"
