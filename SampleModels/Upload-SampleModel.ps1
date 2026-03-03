<#
.SYNOPSIS
    Uploads a sample model ZIP to APS OSS and prints a signed download URL.

.DESCRIPTION
    Reads APS credentials from appsettings.Local.json, uploads a ZIP file to an
    OSS bucket, and prints a 60-minute signed URL ready to paste into
    appsettings.Local.json under DefaultProjects.

.PARAMETER FileName
    Name of the ZIP file inside the SampleModels folder. Defaults to box_2025.zip.

.PARAMETER BucketKey
    OSS bucket key to use. Must be globally unique, lowercase, 3-128 chars.
    Defaults to "sample-models-<first 8 chars of clientId>".

.PARAMETER ObjectKey
    Object name to store in OSS. Defaults to the FileName value.

.EXAMPLE
    .\Upload-SampleModel.ps1
    .\Upload-SampleModel.ps1 -FileName "my_model.zip"
    .\Upload-SampleModel.ps1 -FileName "box_2025.zip" -BucketKey "my-custom-bucket"
#>

param(
    [string]$FileName  = "box_2025.zip",
    [string]$BucketKey = "",
    [string]$ObjectKey = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Resolve paths relative to this script's location
# ---------------------------------------------------------------------------
$scriptDir        = $PSScriptRoot
$projectRoot      = Split-Path $scriptDir -Parent
$appSettingsPath  = Join-Path $projectRoot "WebApplication\appsettings.Local.json"
$filePath         = Join-Path $scriptDir $FileName

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
if (-not (Test-Path $filePath)) {
    Write-Error "File not found: $filePath"
    exit 1
}

if (-not (Test-Path $appSettingsPath)) {
    Write-Error "appsettings.Local.json not found at: $appSettingsPath"
    exit 1
}

# ---------------------------------------------------------------------------
# Read credentials from appsettings.Local.json
# ---------------------------------------------------------------------------
$appSettings = Get-Content $appSettingsPath -Raw | ConvertFrom-Json
$clientId     = $appSettings.Forge.clientId
$clientSecret = $appSettings.Forge.clientSecret

if (-not $clientId -or -not $clientSecret) {
    Write-Error "Could not read Forge.clientId / Forge.clientSecret from appsettings.Local.json"
    exit 1
}

# Default bucket key derived from clientId so it is unique per developer
if (-not $BucketKey) {
    $BucketKey = "sample-models-" + $clientId.Substring(0, [Math]::Min(8, $clientId.Length)).ToLower()
}

if (-not $ObjectKey) {
    $ObjectKey = $FileName
}

Write-Host ""
Write-Host "=== APS OSS Sample Model Upload ===" -ForegroundColor Cyan
Write-Host "File      : $filePath"
Write-Host "Bucket    : $BucketKey"
Write-Host "Object    : $ObjectKey"
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Get bearer token
# ---------------------------------------------------------------------------
Write-Host "[1/5] Getting bearer token..." -ForegroundColor Yellow

$tokenBody = "client_id=$([Uri]::EscapeDataString($clientId))&client_secret=$([Uri]::EscapeDataString($clientSecret))&grant_type=client_credentials&scope=data:read+data:write+data:create+bucket:create+bucket:read"

$tokenResponse = Invoke-RestMethod `
    -Method POST `
    -Uri "https://developer.api.autodesk.com/authentication/v2/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $tokenBody

$token = $tokenResponse.access_token
Write-Host "    Token acquired." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 2. Create bucket (ignore 409 = already exists)
# ---------------------------------------------------------------------------
Write-Host "[2/5] Ensuring bucket '$BucketKey' exists..." -ForegroundColor Yellow

try {
    Invoke-RestMethod `
        -Method POST `
        -Uri "https://developer.api.autodesk.com/oss/v2/buckets" `
        -Headers @{ Authorization = "Bearer $token" } `
        -ContentType "application/json" `
        -Body "{`"bucketKey`": `"$BucketKey`", `"policyKey`": `"persistent`"}" | Out-Null
    Write-Host "    Bucket created." -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "    Bucket already exists." -ForegroundColor Green
    } else {
        throw
    }
}

# ---------------------------------------------------------------------------
# 3. Get signed S3 upload URL
# ---------------------------------------------------------------------------
Write-Host "[3/5] Getting S3 upload URL..." -ForegroundColor Yellow

$uploadInfo = Invoke-RestMethod `
    -Method GET `
    -Uri "https://developer.api.autodesk.com/oss/v2/buckets/$BucketKey/objects/$([Uri]::EscapeDataString($ObjectKey))/signeds3upload" `
    -Headers @{ Authorization = "Bearer $token" }

$uploadUrl = $uploadInfo.urls[0]
$uploadKey = $uploadInfo.uploadKey
Write-Host "    Upload URL obtained." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Upload file directly to S3
# ---------------------------------------------------------------------------
$fileSize = (Get-Item $filePath).Length
Write-Host "[4/5] Uploading $FileName ($([Math]::Round($fileSize / 1MB, 1)) MB) to S3..." -ForegroundColor Yellow

$fileBytes = [System.IO.File]::ReadAllBytes($filePath)

Invoke-RestMethod `
    -Method PUT `
    -Uri $uploadUrl `
    -ContentType "application/octet-stream" `
    -Body $fileBytes | Out-Null

Write-Host "    Upload complete." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Finalise upload with APS
# ---------------------------------------------------------------------------
Write-Host "[5/5] Finalising upload..." -ForegroundColor Yellow

Invoke-RestMethod `
    -Method POST `
    -Uri "https://developer.api.autodesk.com/oss/v2/buckets/$BucketKey/objects/$([Uri]::EscapeDataString($ObjectKey))/signeds3upload" `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType "application/json" `
    -Body "{`"uploadKey`": `"$uploadKey`"}" | Out-Null

Write-Host "    Upload finalised." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Generate signed read URL (60 minutes — enough for initialize run)
# ---------------------------------------------------------------------------
$signed = Invoke-RestMethod `
    -Method POST `
    -Uri "https://developer.api.autodesk.com/oss/v2/buckets/$BucketKey/objects/$([Uri]::EscapeDataString($ObjectKey))/signed" `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType "application/json" `
    -Body '{"minutesExpiration": 60}'

$signedUrl = $signed.signedUrl

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Signed URL (valid 60 min):" -ForegroundColor White
Write-Host $signedUrl -ForegroundColor Green
Write-Host ""
Write-Host "Paste this URL into appsettings.Local.json for the '$($FileName -replace '\.zip$','')' project entry," -ForegroundColor White
Write-Host "then run: dotnet run initialize=true" -ForegroundColor White
Write-Host ""
