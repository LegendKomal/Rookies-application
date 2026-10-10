# Builds store screenshots: a headline on top and a phone mockup showing a
# real app screen underneath. Defaults make the 1080x1920 Play Store set;
# -Src iphone_raw -Out ios_screenshots -W 1290 -H 2796 makes the App Store set.
param([string]$Src = 'phone916', [string]$Out = 'listing_screenshots', [int]$W = 1080, [int]$H = 1920)
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root $Src
$out = Join-Path $root $Out
$k = $W / 1080
New-Item -ItemType Directory -Force $out | Out-Null

$slides = @(
  @{ shot = '1_home';       title = 'STREET STYLE';      sub = 'MADE FOR EVERY DAY' },
  @{ shot = '2_denim';      title = 'SIGNATURE DENIM';    sub = 'JEANS, CARGOS & MORE' },
  @{ shot = '3_categories'; title = 'EXPLORE COLLECTIONS'; sub = 'DENIM, CARGOS & UTILITY' },
  @{ shot = '4_product';    title = 'FIND YOUR FIT';      sub = 'SIZE CHART ON EVERY PRODUCT' },
  @{ shot = '5_cart';       title = 'EASY CHECKOUT';      sub = 'SECURE PAYMENTS, PAN-INDIA DELIVERY' },
  @{ shot = '6_profile';    title = 'YOUR ACCOUNT';       sub = 'ORDERS, ADDRESSES & WISHLIST' }
)

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

$titleFont = New-Object System.Drawing.Font('Segoe UI Black', [float](64 * $k), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$subFont = New-Object System.Drawing.Font('Segoe UI Semibold', [float](34 * $k), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$grey = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 175, 175, 182))
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'

$n = 0
foreach ($s in $slides) {
  $n++
  $bmp = New-Object System.Drawing.Bitmap -ArgumentList $W, $H
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'
  $g.TextRenderingHint = 'AntiAliasGridFit'

  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 0, $H),
    ([System.Drawing.Color]::FromArgb(255, 30, 28, 34)), ([System.Drawing.Color]::FromArgb(255, 6, 6, 8))
  $g.FillRectangle($bg, 0, 0, $W, $H)
  $glow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $glow.AddEllipse(40 * $k, $H * 0.27, $W - 80 * $k, $H * 0.62)
  $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
  $pg.CenterColor = [System.Drawing.Color]::FromArgb(60, 120, 110, 160)
  $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
  $g.FillPath($pg, $glow)

  $g.DrawString($s.title, $titleFont, $white, (New-Object System.Drawing.RectangleF (40 * $k), (150 * $k), ($W - 80 * $k), (90 * $k)), $fmt)
  $g.DrawString($s.sub, $subFont, $grey, (New-Object System.Drawing.RectangleF (40 * $k), (250 * $k), ($W - 80 * $k), (50 * $k)), $fmt)

  # phone: screen keeps the raw screenshot's aspect ratio, inside a bezel
  $img = [System.Drawing.Image]::FromFile((Join-Path $src "$($s.shot).png"))
  $sw = [math]::Round(760 * $k); $sh = [math]::Round($sw * $img.Height / $img.Width); $bz = 18 * $k
  $sx = ($W - $sw) / 2; $sy = [math]::Max(420 * $k, ($H - $sh) / 2 + 100 * $k)
  $px = $sx - $bz; $py = $sy - $bz; $pw = $sw + 2 * $bz; $ph = $sh + 2 * $bz
  for ($i = 8; $i -ge 1; $i--) {
    $sp = RoundRect ($px - $i * 3) ($py - $i * 3 + 14) ($pw + $i * 6) ($ph + $i * 6) (70 * $k + $i * 3)
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(12, 0, 0, 0))), $sp)
  }
  $body = RoundRect $px $py $pw $ph (70 * $k)
  $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 16, 16, 18))), $body)
  $g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 78, 78, 86), 4)), $body)
  $screen = RoundRect $sx $sy $sw $sh (54 * $k)
  $g.SetClip($screen)
  $g.DrawImage($img, $sx, $sy, $sw, $sh)
  $g.ResetClip()
  $img.Dispose()
  $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 8, 8, 8))), ($W / 2 - 13 * $k), ($sy + 22 * $k), (26 * $k), (26 * $k))

  $file = Join-Path $out ("{0}_{1}.png" -f $n, $s.shot.Split('_')[1])
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "saved $file"
}


