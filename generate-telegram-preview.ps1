param([int]$Page = 1, [switch]$RefreshFixtures, [switch]$NightPalette)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$fixture = Join-Path $PSScriptRoot '.tools/telegram-reader-pages.json'
if ($RefreshFixtures -or -not (Test-Path -LiteralPath $fixture)) {
    & node (Join-Path $PSScriptRoot 'scripts/telegram-reader-fixtures.cjs')
    if ($LASTEXITCODE -ne 0) {throw 'Public reader fixture verification failed'}
}
# Keep the outer JSON array intact, including single-card page arrays.
$collection = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json -NoEnumerate
if ($Page -lt 1 -or $Page -gt $collection.Count) {throw ('Page must be between 1 and '+$collection.Count)}
$card = $collection[$Page-1][0]
$bitmap = [Drawing.Bitmap]::new(1920,1080)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$bodyFont = [Drawing.Font]::new('Microsoft YaHei',30,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$color = if ($NightPalette) {'#0C0C0C'} else {'#999999'}
$brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($color))
$format = [Drawing.StringFormat]::new([Drawing.StringFormat]::GenericTypographic)
$format.FormatFlags = [Drawing.StringFormatFlags]::NoWrap
function Draw-ReaderText([string]$Text,[int]$Size,[int]$X,[int]$Y) {
    $labelFont = [Drawing.Font]::new('Microsoft YaHei',$Size,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
    try {$graphics.DrawString($Text,$labelFont,$brush,[Drawing.PointF]::new($X,$Y),$format)}
    finally {$labelFont.Dispose()}
}
try {
    $graphics.Clear([Drawing.Color]::Black)
    $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    Draw-ReaderText '23:48' 110 120 80
    $kind = if ($card.post.isArticle) {'ARTICLE'} else {'MESSAGE'}
    Draw-ReaderText ('TELEGRAM  /  @DNSPODT  /  '+$kind) 28 132 235
    $date = [datetimeoffset]::Parse($card.post.timestamp).ToLocalTime().ToString('MM/dd HH:mm')
    $meta = $date+'  /  Page '+$card.part+' of '+$card.parts
    if ($card.continued) {$meta += '  /  Continued'}
    Draw-ReaderText $meta 20 132 290
    for ($i=0; $i -lt $card.lineTexts.Count; $i++) {
        $graphics.DrawString([string]$card.lineTexts[$i],$bodyFont,$brush,[Drawing.PointF]::new(132,(332+$i*$card.lineHeight)),$format)
    }
    $countdown = '{0}:{1:00}' -f [Math]::Floor($card.duration/60),($card.duration%60)
    Draw-ReaderText ('Full text  /  Next page in '+$countdown) 20 132 945
    $credit = 't.me/DNSPODT/'+$card.post.id
    if ($card.post.isArticle) {
        $credit = 'Article: telegra.ph  /  '+$credit
        if ($card.post.author) {$credit += '  /  '+$card.post.author}
    }
    Draw-ReaderText $credit 18 132 985
    $outputDirectory = Join-Path $PSScriptRoot 'dist/previews'
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $suffix = if ($NightPalette) {'night'} else {'readable'}
    $output = Join-Path $outputDirectory ('telegram-page-'+$Page+'-'+$suffix+'.png')
    $bitmap.Save($output,[Drawing.Imaging.ImageFormat]::Png)
    Write-Output ('Created '+$output+' (simulated font metrics, not a Roku capture)')
} finally {$format.Dispose();$brush.Dispose();$bodyFont.Dispose();$graphics.Dispose();$bitmap.Dispose()}
