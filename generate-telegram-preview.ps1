param([int]$Page = 1)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'generate-previews.ps1')
$html = (Invoke-WebRequest -UseBasicParsing -Uri 'https://t.me/s/DNSPODT').Content
$pattern = '<div[^>]*data-post="DNSPODT/([0-9]+)"[^>]*>'
$markers = [regex]::Matches($html, $pattern)
$posts = @()
for ($i = 0; $i -lt $markers.Count; $i++) {
    $start = $markers[$i].Index
    $end = if ($i+1 -lt $markers.Count) {$markers[$i+1].Index} else {$html.Length}
    $body = $html.Substring($start, $end-$start)
    $textStart = [regex]::Match($body, '<div[^>]*class="[^"]*\btgme_widget_message_text\b[^"]*"[^>]*>')
    if (-not $textStart.Success) {continue}
    $remaining = $body.Substring($textStart.Index + $textStart.Length)
    $depth = 1
    $textEnd = -1
    foreach ($tag in [regex]::Matches($remaining, '<div\b[^>]*>|</div\s*>', 'IgnoreCase')) {
        if ($tag.Value.StartsWith('</')) {$depth--} else {$depth++}
        if ($depth -eq 0) {$textEnd=$tag.Index; break}
    }
    if ($textEnd -lt 0) {continue}
    $text = $remaining.Substring(0,$textEnd)
    $text = [regex]::Replace($text,'<br\s*/?>|</(p|div|blockquote)\s*>',' ')
    $text = [regex]::Replace($text,'<[^>]*>','')
    $text = [Net.WebUtility]::HtmlDecode($text)
    $text = [regex]::Replace($text,'\s+',' ').Trim()
    $date = [regex]::Match($body,'<time[^>]*datetime="([^"]+)"')
    if ($text -and $date.Success) {$posts += @{Id=[int]$markers[$i].Groups[1].Value;Text=$text;Date=[datetimeoffset]::Parse($date.Groups[1].Value)}}
}
$posts = @($posts | Sort-Object {$_.Id} -Descending | Select-Object -First 6)
if ($posts.Count -lt 2) {throw 'Public feed has too few text posts for a preview'}
$bitmap = [Drawing.Bitmap]::new(1920,1080)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$font = [Drawing.Font]::new('Microsoft YaHei',26,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$brush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#999999'))
$format = [Drawing.StringFormat]::new([Drawing.StringFormat]::GenericTypographic)
$format.FormatFlags = [Drawing.StringFormatFlags]::MeasureTrailingSpaces
function Text-Width([string]$Text) {return $graphics.MeasureString($Text,$font,100000,$format).Width}
try {
    $graphics.Clear([Drawing.Color]::Black)
    $graphics.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    Write-PreviewText $graphics '23:48' 110 120 80 '#999999'
    Write-PreviewText $graphics 'TELEGRAM  /  @DNSPODT  /  RECENT POSTS' 28 132 270 '#999999'
    $heights=@(0,0)
    $lineHeight=[Math]::Max(32,[Math]::Ceiling($font.GetHeight($graphics))+2)
    $pages=[Collections.Generic.List[object]]::new()
    $cards=[Collections.Generic.List[object]]::new()
    $capacity=[Math]::Floor((620-60)/$lineHeight)
    for ($i=0;$i -lt $posts.Count;$i++) {
        $lines=[Collections.Generic.List[string]]::new()
        $line=''
        foreach($char in $posts[$i].Text.ToCharArray()) {
            if((Text-Width ($line+$char)) -gt 780 -and $line) {
                $splitAt=$line.LastIndexOf(' ')
                $carry=[string]$char
                if($splitAt -gt $line.Length/2) {$carry=$line.Substring($splitAt+1)+$char; $line=$line.Substring(0,$splitAt)}
                $lines.Add($line.Trim()); $line=$carry.Trim()
            } else {$line+=$char}
        }
        if($line.Trim()){$lines.Add($line.Trim())}
        $offset=0
        while($offset -lt $lines.Count) {
            $column=if($heights[1] -lt $heights[0]){1}else{0}
            $remaining=$lines.Count-$offset
            $room=[Math]::Floor((620-$heights[$column]-60)/$lineHeight)
            if($room -lt 1 -or ($remaining -le $capacity -and $remaining -gt $room)) {
                if($cards.Count){$pages.Add($cards)}
                $cards=[Collections.Generic.List[object]]::new()
                $heights=@(0,0);$column=0;$room=$capacity
            }
            $count=[int][Math]::Min($remaining,$room)
            $part=@()
            for($j=$offset;$j -lt $offset+$count;$j++) {$part+=$lines[$j]}
            $cards.Add(@{Post=$posts[$i];X=132+$column*860;Y=345+$heights[$column];Lines=$part;Continued=$offset -gt 0})
            $heights[$column]+=$count*$lineHeight+60
            $offset+=$count
        }
    }
    if($cards.Count){$pages.Add($cards)}
    if($Page -lt 1 -or $Page -gt $pages.Count){throw ('Page must be between 1 and '+$pages.Count)}
    foreach($card in $pages[$Page-1]) {
        $meta=$card.Post.Date.ToLocalTime().ToString('MM/dd HH:mm')+'  /  t.me/DNSPODT/'+$card.Post.Id
        if($card.Continued){$meta+='  /  Continued'}
        Write-PreviewText $graphics $meta 20 $card.X $card.Y '#777777'
        for($j=0;$j -lt $card.Lines.Count;$j++) {
            $graphics.DrawString($card.Lines[$j],$font,$brush,[Drawing.PointF]::new($card.X,($card.Y+35+$j*$lineHeight)),$format)
        }
    }
    Write-PreviewText $graphics ('https://t.me/DNSPODT  /  Page '+$Page+' of '+$pages.Count+'  /  Full text  /  1 minute per visit') 20 132 985 '#777777'
    $bitmap.Save((Join-Path $PSScriptRoot "dist/previews/telegram-page-$Page-readable.png"),[Drawing.Imaging.ImageFormat]::Png)
    Write-Output ('Preview page '+$Page+' of '+$pages.Count)
} finally {$format.Dispose();$brush.Dispose();$font.Dispose();$graphics.Dispose();$bitmap.Dispose()}
