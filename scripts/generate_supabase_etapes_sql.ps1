param(
  [string]$InputPath = "database/bigquery_recette_etapes.csv",
  [string]$OutputPath = "database/supabase_update_etapes.sql"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InputPath)) {
  throw "Input CSV not found: $InputPath"
}

function Escape-SqlLiteral([string]$Value) {
  if ($null -eq $Value) {
    return ""
  }

  return $Value.Replace("'", "''")
}

$rows = Import-Csv -LiteralPath $InputPath
$lines = [System.Collections.Generic.List[string]]::new()

$lines.Add("-- Adds preparation steps imported from BigQuery/Dataiku.") | Out-Null
$lines.Add("-- Run after database/supabase_schema.sql and database/supabase_seed_data.sql.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("begin;") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("alter table fact_recette_base add column if not exists etapes text default '';") | Out-Null
$lines.Add("") | Out-Null

foreach ($row in $rows) {
  $recetteId = Escape-SqlLiteral $row.recette_id
  $etapes = Escape-SqlLiteral $row.etapes
  $lines.Add("update fact_recette_base set etapes = '$etapes' where recette_id = '$recetteId';") | Out-Null
}

$lines.Add("") | Out-Null
$lines.Add("commit;") | Out-Null

$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath
} else {
  Join-Path (Get-Location) $OutputPath
}

$outputDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

Set-Content -LiteralPath $resolvedOutput -Value $lines -Encoding UTF8
Write-Host "Wrote $($rows.Count) recipe step updates to $resolvedOutput"
