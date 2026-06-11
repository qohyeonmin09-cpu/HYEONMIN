param(
    [int]$Port = 5173
)

$ErrorActionPreference = "Stop"
$root = Join-Path $PSScriptRoot "web-app"
$prefix = "http://localhost:$Port/"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)

function Get-ContentType {
    param([string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { "text/html; charset=utf-8" }
        ".css" { "text/css; charset=utf-8" }
        ".js" { "text/javascript; charset=utf-8" }
        ".json" { "application/json; charset=utf-8" }
        ".png" { "image/png" }
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".svg" { "image/svg+xml" }
        default { "application/octet-stream" }
    }
}

try {
    $listener.Start()
    Write-Host "TimeTableAlarm web app is running at $prefix"

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $requestPath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))

        if ([string]::IsNullOrWhiteSpace($requestPath)) {
            $requestPath = "index.html"
        }

        $candidate = Join-Path $root $requestPath
        $resolved = [System.IO.Path]::GetFullPath($candidate)
        $rootResolved = [System.IO.Path]::GetFullPath($root)

        if (-not $resolved.StartsWith($rootResolved, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            $context.Response.StatusCode = 404
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("Not found")
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.Close()
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($resolved)
        $context.Response.ContentType = Get-ContentType -Path $resolved
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.Close()
    }
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
