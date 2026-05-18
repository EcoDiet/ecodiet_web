param(
  [int]$Port = 8080,
  [string]$Root = "build/web"
)

$ErrorActionPreference = "Stop"
$rootPath = Resolve-Path -LiteralPath $Root
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "Serving $rootPath at http://localhost:$Port/"

$mimeTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".js" = "application/javascript; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".png" = "image/png"
  ".jpg" = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".svg" = "image/svg+xml"
  ".wasm" = "application/wasm"
  ".ico" = "image/x-icon"
}

function Send-Response($Stream, [int]$Status, [string]$ContentType, [byte[]]$Body) {
  $statusText = if ($Status -eq 200) { "OK" } elseif ($Status -eq 404) { "Not Found" } else { "Internal Server Error" }
  $header = "HTTP/1.1 $Status $statusText`r`nContent-Type: $ContentType`r`nContent-Length: $($Body.Length)`r`nConnection: close`r`n`r`n"
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
  $Stream.Write($headerBytes, 0, $headerBytes.Length)
  $Stream.Write($Body, 0, $Body.Length)
}

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $buffer = New-Object byte[] 8192
    $read = $stream.Read($buffer, 0, $buffer.Length)
    $request = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
    $firstLine = ($request -split "`r?`n")[0]
    $parts = $firstLine -split " "
    $path = if ($parts.Length -ge 2) { $parts[1] } else { "/" }
    $relativePath = [Uri]::UnescapeDataString($path.Split("?")[0].TrimStart("/"))
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
      $relativePath = "index.html"
    }

    $filePath = Join-Path $rootPath $relativePath
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
      $filePath = Join-Path $rootPath "index.html"
    }

    $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
    $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    Send-Response $stream 200 $contentType $bytes
  } catch {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($_.Exception.Message)
    Send-Response $stream 500 "text/plain; charset=utf-8" $bytes
  } finally {
    $client.Close()
  }
}
