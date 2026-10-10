# Builds the 1024x500 Play Store feature graphic: logo + tagline on the left,
# three phone mockups showing real app screens on the right.
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$raw = Join-Path $root 'raw'

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

function DrawPhone($g, [string]$shot, [float]$cx, [float]$top, [float]$h) {
  $w = $h * 0.47
  $x = $cx - $w / 2
  $bezel = 7
  # soft shadow
  for ($i = 6; $i -ge 1; $i--) {
    $sp = RoundRect ($x - $i * 2 + 6) ($top - $i * 2 + 10) ($w + $i * 4) ($h + $i * 4) (30 + $i * 2)
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(10, 0, 0, 0))), $sp)
  }
  $body = RoundRect $x $top $w $h 30
  $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 18, 18, 20))), $body)
  $g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 70, 70, 76)), 2), $body)
  $sx = $x + $bezel; $sy = $top + $bezel; $sw = $w - 2 * $bezel; $sh = $h - 2 * $bezel
  $screen = RoundRect $sx $sy $sw $sh 24
  $img = [System.Drawing.Image]::FromFile((Join-Path $raw "$shot.png"))
  $g.SetClip($screen)
  # crop the screenshot to the screen's aspect ratio, anchored at the top
  $srcH = [math]::Min($img.Height, $img.Width * $sh / $sw)
  $g.DrawImage($img, (New-Object System.Drawing.RectangleF $sx, $sy, $sw, $sh),
    (New-Object System.Drawing.RectangleF 0, 0, $img.Width, $srcH), [System.Drawing.GraphicsUnit]::Pixel)
  $g.ResetClip()
  $img.Dispose()
  # camera dot
  $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 10, 10, 10))), ($cx - 5), ($sy + 9), 10, 10)
}

$bmp = New-Object System.Drawing.Bitmap 1024, 500
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.TextRenderingHint = 'AntiAliasGridFit'

# background: near-black with a subtle warm glow behind the phones
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 1024, 500),
  ([System.Drawing.Color]::FromArgb(255, 8, 8, 10)), ([System.Drawing.Color]::FromArgb(255, 28, 26, 30))
$g.FillRectangle($bg, 0, 0, 1024, 500)
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(470, -60, 560, 620)
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$pg.CenterColor = [System.Drawing.Color]::FromArgb(70, 120, 110, 160)
$pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
$g.FillPath($pg, $glow)

# left: logo (the icon PNG is 512x512 with the mark in its middle band)
$logo = [System.Drawing.Image]::FromFile((Resolve-Path (Join-Path $root '..\assets\app_icon.png')))
# key out the icon's black background so only the white mark is drawn
$ia = New-Object System.Drawing.Imaging.ImageAttributes
$ia.SetColorKey([System.Drawing.Color]::FromArgb(0, 0, 0), [System.Drawing.Color]::FromArgb(90, 90, 90))
$g.DrawImage($logo, (New-Object System.Drawing.Rectangle 30, 70, 420, 210), 0, 128, 512, 256, [System.Drawing.GraphicsUnit]::Pixel, $ia)
$logo.Dispose()

$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$grey = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 185, 185, 190))
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'
$g.DrawString('Denim. Cargos. Street style.', (New-Object System.Drawing.Font('Segoe UI', 21, [System.Drawing.FontStyle]::Bold)), $white,
  (New-Object System.Drawing.RectangleF 20, 300, 440, 44), $fmt)
$g.DrawString('Shop the full ROOKIES collection', (New-Object System.Drawing.Font('Segoe UI', 15)), $grey,
  (New-Object System.Drawing.RectangleF 20, 348, 440, 30), $fmt)
$g.DrawString('Pan-India delivery', (New-Object System.Drawing.Font('Segoe UI', 15)), $grey,
  (New-Object System.Drawing.RectangleF 20, 374, 440, 30), $fmt)

# right: three phones, the middle one in front
DrawPhone $g 'home6' 612 70 390
DrawPhone $g 'product' 910 70 390
DrawPhone $g 'home' 761 35 440

$out = Join-Path $root 'feature_graphic.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "saved $out"

