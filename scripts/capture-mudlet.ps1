# Capture the Mudlet window to a PNG. Called by
# scripts/screenshot.sh. Uses PrintWindow with
# PW_RENDERFULLCONTENT (0x2) so we get the actual Qt-rendered
# contents even when Mudlet is occluded — plain BitBlt against
# the desktop DC would miss it.

param(
    [Parameter(Mandatory=$true)][string]$OutPath
)

Add-Type @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr GetWindowDC(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hDC, uint nFlags);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@ -ReferencedAssemblies System.Drawing -ErrorAction SilentlyContinue | Out-Null

# Find the Mudlet window. Process is named "Mudlet". Pick the
# one whose MainWindowHandle is non-zero (Mudlet sometimes
# spawns a background helper without a window).
$proc = Get-Process -Name "Mudlet" -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

if (-not $proc) {
    Write-Error "Mudlet process not found (no visible window)."
    exit 2
}

$hWnd = $proc.MainWindowHandle

if ([Win32]::IsIconic($hWnd)) {
    Write-Error "Mudlet is minimized; restore it before capturing."
    exit 3
}

$rect = New-Object Win32+RECT
if (-not [Win32]::GetWindowRect($hWnd, [ref]$rect)) {
    Write-Error "GetWindowRect failed."
    exit 4
}

$width  = $rect.Right  - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
    Write-Error "Mudlet window has zero size."
    exit 5
}

$bmp = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$hDC = $gfx.GetHdc()
try {
    # PW_RENDERFULLCONTENT = 0x00000002 — paints Qt/composited
    # contents into the bitmap. Without this, Qt windows
    # frequently come back as a blank rectangle.
    $ok = [Win32]::PrintWindow($hWnd, $hDC, 0x00000002)
    if (-not $ok) { throw "PrintWindow returned false." }
}
finally {
    $gfx.ReleaseHdc($hDC)
    $gfx.Dispose()
}

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output ("captured {0}x{1} to {2}" -f $width, $height, $OutPath)
