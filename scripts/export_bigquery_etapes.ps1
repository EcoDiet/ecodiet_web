param(
  [Parameter(Mandatory = $true)]
  [string]$CredentialPath,

  [string]$OutputPath = "database/bigquery_recette_etapes.csv",

  [string]$DatasetId = "dataiku",

  [string]$TableId = "node_7e227912_ECODIETYNOV_fact_recette_base"
)

$ErrorActionPreference = "Stop"

function ConvertTo-Base64Url([byte[]]$Bytes) {
  return [Convert]::ToBase64String($Bytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function ConvertTextTo-Base64Url([string]$Text) {
  return ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($Text))
}

function New-ServiceAccountAccessToken($Credential) {
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
  $claims = @{
    iss   = $Credential.client_email
    scope = "https://www.googleapis.com/auth/bigquery.readonly"
    aud   = $Credential.token_uri
    iat   = $now
    exp   = $now + 3600
  } | ConvertTo-Json -Compress

  $unsignedJwt = "$(ConvertTextTo-Base64Url $header).$(ConvertTextTo-Base64Url $claims)"
  $pem = [string]$Credential.private_key
  $pkcs8 = $pem `
    -replace "-----BEGIN PRIVATE KEY-----", "" `
    -replace "-----END PRIVATE KEY-----", "" `
    -replace "\s", ""
  $keyBytes = [Convert]::FromBase64String($pkcs8)
  $cngKey = [System.Security.Cryptography.CngKey]::Import(
    $keyBytes,
    [System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob
  )
  $rsa = [System.Security.Cryptography.RSACng]::new($cngKey)
  $signature = $rsa.SignData(
    [Text.Encoding]::UTF8.GetBytes($unsignedJwt),
    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
  )
  $jwt = "$unsignedJwt.$(ConvertTo-Base64Url $signature)"

  $tokenResponse = Invoke-RestMethod `
    -Method Post `
    -Uri $Credential.token_uri `
    -ContentType "application/x-www-form-urlencoded" `
    -Body @{
      grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
      assertion  = $jwt
    }

  return $tokenResponse.access_token
}

function Get-BigQueryRows($ProjectId, $AccessToken, $Query) {
  $headers = @{ Authorization = "Bearer $AccessToken" }
  $queryUri = "https://bigquery.googleapis.com/bigquery/v2/projects/$ProjectId/queries"
  $body = @{
    query        = $Query
    useLegacySql = $false
    maxResults   = 1000
    timeoutMs    = 30000
  } | ConvertTo-Json -Depth 5

  $response = Invoke-RestMethod `
    -Method Post `
    -Uri $queryUri `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $body

  while (-not $response.jobComplete) {
    Start-Sleep -Seconds 1
    $resultUri = "https://bigquery.googleapis.com/bigquery/v2/projects/$ProjectId/queries/$($response.jobReference.jobId)?location=$($response.jobReference.location)&maxResults=1000"
    $response = Invoke-RestMethod -Method Get -Uri $resultUri -Headers $headers
  }

  $fields = @($response.schema.fields | ForEach-Object { $_.name })
  $rows = [System.Collections.Generic.List[object]]::new()

  function Add-Rows($Page) {
    foreach ($row in @($Page.rows)) {
      $object = [ordered]@{}
      for ($i = 0; $i -lt $fields.Count; $i++) {
        $object[$fields[$i]] = $row.f[$i].v
      }
      $rows.Add([pscustomobject]$object) | Out-Null
    }
  }

  Add-Rows $response

  while ($response.pageToken) {
    $pageUri = "https://bigquery.googleapis.com/bigquery/v2/projects/$ProjectId/queries/$($response.jobReference.jobId)?location=$($response.jobReference.location)&maxResults=1000&pageToken=$($response.pageToken)"
    $response = Invoke-RestMethod -Method Get -Uri $pageUri -Headers $headers
    Add-Rows $response
  }

  return $rows
}

if (-not (Test-Path -LiteralPath $CredentialPath)) {
  throw "Credential file not found: $CredentialPath"
}

$credential = Get-Content -LiteralPath $CredentialPath -Raw | ConvertFrom-Json
$projectId = $credential.project_id
$fullTableName = "$projectId.$DatasetId.$TableId"

$query = @"
select
  recette_id,
  titre,
  photo,
  etapes,
  duree_minute,
  temps_bin_id
from ``$fullTableName``
order by duree_minute, titre
"@

Write-Host "Connecting to BigQuery project $projectId..."
$accessToken = New-ServiceAccountAccessToken $credential
$rows = Get-BigQueryRows -ProjectId $projectId -AccessToken $accessToken -Query $query

$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath
} else {
  Join-Path (Get-Location) $OutputPath
}

$outputDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$rows | Export-Csv -LiteralPath $resolvedOutput -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($rows.Count) rows to $resolvedOutput"
