param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string]$OutputDir = (Join-Path (Get-Location) 'prezi_download')
)

$ErrorActionPreference = 'Stop'

function Get-SafeName {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return 'presentation'
    }

    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $chars = $Value.ToCharArray() | ForEach-Object {
        if ($invalid -contains $_) { '_' } else { $_ }
    }

    return (-join $chars).Trim()
}

function Save-TextFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function Resolve-AssetUrls {
    param([string]$Html)

    $patterns = @(
        'https://[^''"<> ]+',
        '(?<=["''])//[^''"<> ]+',
        '(?<=["''])/[^''"<> ]+\.(?:jpg|jpeg|png|webp|gif|svg|mp4|webm|m3u8|json|js|css)(?:\?[^''"<> ]*)?'
    )

    $results = New-Object System.Collections.Generic.HashSet[string]

    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Html, $pattern, 'IgnoreCase')) {
            $value = $match.Value
            if ($value.StartsWith('//')) {
                $value = "https:$value"
            }

            [void]$results.Add($value)
        }
    }

    return $results.ToArray() | Sort-Object
}

function Convert-ToAbsoluteUrl {
    param(
        [Uri]$BaseUri,
        [string]$Candidate
    )

    if ($Candidate.StartsWith('http://') -or $Candidate.StartsWith('https://')) {
        return $Candidate
    }

    try {
        return ([Uri]::new($BaseUri, $Candidate)).AbsoluteUri
    }
    catch {
        return $null
    }
}

function Get-ExtensionFromUrl {
    param([string]$AssetUrl)

    try {
        $uri = [Uri]$AssetUrl
        $ext = [System.IO.Path]::GetExtension($uri.AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($ext)) {
            return '.bin'
        }

        return $ext
    }
    catch {
        return '.bin'
    }
}

$targetUri = [Uri]$Url
$downloadRoot = Join-Path $OutputDir (Get-SafeName $targetUri.Segments[-1])
$assetsDir = Join-Path $downloadRoot 'assets'

New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null

$response = Invoke-WebRequest -Uri $Url -Headers @{
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell Prezi Downloader'
}

$htmlPath = Join-Path $downloadRoot 'presentation.html'
Save-TextFile -Path $htmlPath -Content $response.Content

$assetUrls = Resolve-AssetUrls -Html $response.Content |
    ForEach-Object { Convert-ToAbsoluteUrl -BaseUri $targetUri -Candidate $_ } |
    Where-Object { $_ } |
    Select-Object -Unique

$downloaded = @()
$failed = @()
$index = 1

foreach ($assetUrl in $assetUrls) {
    $extension = Get-ExtensionFromUrl -AssetUrl $assetUrl
    $fileName = '{0:D3}{1}' -f $index, $extension
    $destination = Join-Path $assetsDir $fileName

    try {
        Invoke-WebRequest -Uri $assetUrl -OutFile $destination -Headers @{
            'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell Prezi Downloader'
            'Referer' = $Url
        }

        $downloaded += [pscustomobject]@{
            url = $assetUrl
            file = $fileName
        }
        $index += 1
    }
    catch {
        $failed += [pscustomobject]@{
            url = $assetUrl
            error = $_.Exception.Message
        }
    }
}

$manifest = [pscustomobject]@{
    source_url = $Url
    saved_html = 'presentation.html'
    downloaded_assets = $downloaded
    failed_assets = $failed
    note = 'This script saves the publicly accessible Prezi page HTML and direct asset URLs it can discover. It does not export a private/offline-native Prezi project or bypass protected content.'
}

$manifestPath = Join-Path $downloadRoot 'manifest.json'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Saved page to: $htmlPath"
Write-Host "Saved manifest to: $manifestPath"
Write-Host "Downloaded assets: $($downloaded.Count)"
Write-Host "Failed assets: $($failed.Count)"
