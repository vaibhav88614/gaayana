Add-Type -AssemblyName System.Drawing

function Make-Icon([int]$size, [string]$out, [bool]$rounded) {
  $bmp = New-Object System.Drawing.Bitmap $size,$size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'
  $g.Clear([System.Drawing.Color]::Transparent)

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  if ($rounded) {
    $r = [single]($size * 0.22)
    $d = $r * 2.0
    $sf = [single]$size
    $path.AddArc([single]0, [single]0, $d, $d, [single]180, [single]90)
    $path.AddArc(($sf - $d), [single]0, $d, $d, [single]270, [single]90)
    $path.AddArc(($sf - $d), ($sf - $d), $d, $d, [single]0, [single]90)
    $path.AddArc([single]0, ($sf - $d), $d, $d, [single]90, [single]90)
    $path.CloseFigure()
  } else {
    $path.AddRectangle((New-Object System.Drawing.RectangleF 0,0,$size,$size))
  }

  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point 0,0),
    (New-Object System.Drawing.Point $size,$size),
    [System.Drawing.Color]::FromArgb(255,124,58,237),
    [System.Drawing.Color]::FromArgb(255,30,27,75))
  $g.FillPath($bgBrush, $path)

  $glowBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF 0,0),
    (New-Object System.Drawing.PointF 0,([single]($size*0.9))),
    [System.Drawing.Color]::FromArgb(80,255,255,255),
    [System.Drawing.Color]::FromArgb(0,255,255,255))
  $g.FillEllipse($glowBrush,
    [single]($size*0.05),[single]($size*0.05),
    [single]($size*0.90),[single]($size*0.65))

  $gold  = [System.Drawing.Color]::FromArgb(255,253,224,138)
  $amber = [System.Drawing.Color]::FromArgb(255,245,158,11)
  $noteBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF ([single]($size*0.40)),([single]($size*0.20))),
    (New-Object System.Drawing.PointF ([single]($size*0.60)),([single]($size*0.80))),
    $gold, $amber)
  $stroke = New-Object System.Drawing.Pen($gold, [single]($size*0.034))
  $stroke.StartCap = 'Round'; $stroke.EndCap = 'Round'
  $faint = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140,253,224,138), [single]($size*0.034))
  $faint.StartCap='Round'; $faint.EndCap='Round'

  $g.DrawArc($stroke, [single]($size*0.16),[single]($size*0.40),
                       [single]($size*0.16),[single]($size*0.20), [single]90, [single]90)
  $g.DrawArc($stroke, [single]($size*0.16),[single]($size*0.40),
                       [single]($size*0.16),[single]($size*0.20), [single]180, [single]90)
  $g.DrawArc($faint,  [single]($size*0.06),[single]($size*0.32),
                       [single]($size*0.22),[single]($size*0.36), [single]90, [single]180)

  $g.DrawArc($stroke, [single]($size*0.68),[single]($size*0.40),
                       [single]($size*0.16),[single]($size*0.20), [single]0, [single]90)
  $g.DrawArc($stroke, [single]($size*0.68),[single]($size*0.40),
                       [single]($size*0.16),[single]($size*0.20), [single]270, [single]90)
  $g.DrawArc($faint,  [single]($size*0.72),[single]($size*0.32),
                       [single]($size*0.22),[single]($size*0.36), [single]270, [single]180)

  $stemRect = New-Object System.Drawing.RectangleF (
    [single]($size*0.54)),([single]($size*0.27)),([single]($size*0.04)),([single]($size*0.38))
  $g.FillRectangle($noteBrush, $stemRect)

  $flag = New-Object System.Drawing.Drawing2D.GraphicsPath
  $flag.AddBezier(
    [single]($size*0.58),[single]($size*0.27),
    [single]($size*0.74),[single]($size*0.31),
    [single]($size*0.78),[single]($size*0.42),
    [single]($size*0.66),[single]($size*0.48))
  $flag.AddBezier(
    [single]($size*0.66),[single]($size*0.48),
    [single]($size*0.72),[single]($size*0.42),
    [single]($size*0.70),[single]($size*0.36),
    [single]($size*0.58),[single]($size*0.36))
  $flag.CloseFigure()
  $g.FillPath($noteBrush, $flag)

  $st = $g.Save()
  $g.TranslateTransform([single]($size*0.485),[single]($size*0.66))
  $g.RotateTransform(-18)
  $headRect = New-Object System.Drawing.RectangleF (
    [single](-$size*0.10)),([single](-$size*0.065)),([single]($size*0.20)),([single]($size*0.13))
  $g.FillEllipse($noteBrush, $headRect)
  $g.Restore($st)

  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Host "Wrote $out ($size px, rounded=$rounded)"
}

$root = "V:\temp\NewProj\assets\logo"
New-Item -ItemType Directory -Force -Path $root | Out-Null
Make-Icon 1024 "$root\gaayana_logo.png"            $true
Make-Icon 1024 "$root\gaayana_logo_square.png"     $false
Make-Icon 1024 "$root\gaayana_logo_foreground.png" $false
