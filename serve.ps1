param(
  [int]$Port = 8000
)

Add-Type -AssemblyName System.Net.HttpListener
$prefix = "http://127.0.0.1:$Port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $PWD at $prefix (Ctrl+C to stop)"

function Get-ContentType($path) {
  switch ([System.IO.Path]::GetExtension($path).ToLower()) {
    ".html" { "text/html; charset=utf-8" }
    ".css"  { "text/css; charset=utf-8" }
    ".js"   { "application/javascript; charset=utf-8" }
    ".json" { "application/json; charset=utf-8" }
    ".png"  { "image/png" }
    ".jpg"  { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".ico"  { "image/x-icon" }
    ".svg"  { "image/svg+xml" }
    default { "application/octet-stream" }
  }
}

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response

    $relPath = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relPath)) { $relPath = 'index.html' }
    $filePath = Join-Path -Path (Get-Location) -ChildPath $relPath

    if ((Test-Path $filePath) -and -not (Get-Item $filePath).PSIsContainer) {
      try {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $res.StatusCode = 200
        $res.ContentType = Get-ContentType $filePath
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
      } catch {
        $res.StatusCode = 500
        $err = [System.Text.Encoding]::UTF8.GetBytes("Internal Server Error")
        $res.OutputStream.Write($err, 0, $err.Length)
      }
    } else {
      $res.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
      $res.OutputStream.Write($msg, 0, $msg.Length)
    }
    $res.OutputStream.Close()
  }
} finally {
  $listener.Stop()
  $listener.Close()
}

