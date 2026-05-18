param(
  [Parameter(Mandatory = $true)]
  [string]$CsvDir,

  [string]$Output = "database/supabase_seed_data.sql"
)

$ErrorActionPreference = "Stop"

function SqlText($Value) {
  if ($null -eq $Value) {
    return "''"
  }

  $text = [string]$Value
  return "'" + ($text -replace "'", "''") + "'"
}

function SqlInt($Value) {
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    return "0"
  }

  return [string][int]$Value
}

function Read-CsvFile($Name) {
  $path = Join-Path $CsvDir $Name
  if (-not (Test-Path -LiteralPath $path)) {
    throw "Missing CSV file: $path"
  }

  return Import-Csv -LiteralPath $path -Encoding UTF8
}

function Add-Insert($Lines, $Table, $Columns, $Values) {
  $Lines.Add("insert into $Table ($($Columns -join ', ')) values ($($Values -join ', '));") | Out-Null
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("-- Generated from DIM/FACT CSV files for EcoDiet Supabase.") | Out-Null
$lines.Add("-- Run database/supabase_schema.sql first, then run this file.") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("begin;") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("truncate table") | Out-Null
$lines.Add("  fact_recette_type_plat,") | Out-Null
$lines.Add("  fact_recette_regime,") | Out-Null
$lines.Add("  fact_recette_occasion,") | Out-Null
$lines.Add("  fact_recette_equipement,") | Out-Null
$lines.Add("  fact_recette_allergene,") | Out-Null
$lines.Add("  fact_ingredients_recette,") | Out-Null
$lines.Add("  fact_recette_base,") | Out-Null
$lines.Add("  dim_temps_bin,") | Out-Null
$lines.Add("  dim_type_plat,") | Out-Null
$lines.Add("  dim_regime,") | Out-Null
$lines.Add("  dim_occasion,") | Out-Null
$lines.Add("  dim_ingredient,") | Out-Null
$lines.Add("  dim_equipement,") | Out-Null
$lines.Add("  dim_allergene") | Out-Null
$lines.Add("restart identity cascade;") | Out-Null
$lines.Add("") | Out-Null

foreach ($row in Read-CsvFile "DIM_ALLERGENE.csv") {
  Add-Insert $lines "dim_allergene" @("allergene_id", "libelle") @(
    (SqlInt $row.allergene_id),
    (SqlText $row.libelle)
  )
}

foreach ($row in Read-CsvFile "DIM_EQUIPEMENT.csv") {
  Add-Insert $lines "dim_equipement" @("equipement_id", "nom_equipement") @(
    (SqlInt $row.equipement_id),
    (SqlText $row.nom_equipement)
  )
}

foreach ($row in Read-CsvFile "DIM_INGREDIENTS.csv") {
  Add-Insert $lines "dim_ingredient" @("ingredient_id", "nom_ingredient") @(
    (SqlInt $row.ingredient_id),
    (SqlText $row.nom_ingredient)
  )
}

foreach ($row in Read-CsvFile "DIM_OCCASION.csv") {
  Add-Insert $lines "dim_occasion" @("occasion_id", "libelle") @(
    (SqlInt $row.occasion_id),
    (SqlText $row.libelle)
  )
}

foreach ($row in Read-CsvFile "DIM_REGIME.csv") {
  Add-Insert $lines "dim_regime" @("regime_id", "libelle") @(
    (SqlInt $row.regime_id),
    (SqlText $row.libelle)
  )
}

foreach ($row in Read-CsvFile "DIM_TYPE_PLAT.csv") {
  Add-Insert $lines "dim_type_plat" @("type_plat_id", "libelle") @(
    (SqlInt $row.type_plat_id),
    (SqlText $row.libelle)
  )
}

foreach ($row in Read-CsvFile "DIM_TEMPS_BIN.csv") {
  Add-Insert $lines "dim_temps_bin" @("temps_bin_id", "libelle", "min_minutes", "max_minutes") @(
    (SqlInt $row.temps_bin_id),
    (SqlText $row.libelle),
    (SqlInt $row.min_minutes),
    (SqlInt $row.max_minutes)
  )
}

foreach ($row in Read-CsvFile "FACT_RECETTE_BASE.csv") {
  Add-Insert $lines "fact_recette_base" @("recette_id", "titre", "photo", "duree_minute", "temps_bin_id") @(
    (SqlText $row.recette_id),
    (SqlText $row.titre),
    (SqlText $row.photo),
    (SqlInt $row.duree_minute),
    (SqlInt $row.temps_bin_id)
  )
}

foreach ($row in Read-CsvFile "FACT_INGREDIENTS_RECETTE.csv") {
  Add-Insert $lines "fact_ingredients_recette" @("recette_id", "ingredient_id") @(
    (SqlText $row.recette_id),
    (SqlInt $row.ingredient_id)
  )
}

foreach ($row in Read-CsvFile "FACT_RECETTE_ALLERGENE.csv") {
  Add-Insert $lines "fact_recette_allergene" @("recette_id", "allergene_id") @(
    (SqlText $row.recette_id),
    (SqlInt $row.allergene_id)
  )
}

foreach ($row in Read-CsvFile "FACT_RECETTE_EQUIPEMENTS.csv") {
  Add-Insert $lines "fact_recette_equipement" @("recette_id", "equipement_id") @(
    (SqlText $row.recette_id),
    (SqlInt $row.equipement_id)
  )
}

foreach ($row in Read-CsvFile "FACT_RECETTE_OCCASION.csv") {
  Add-Insert $lines "fact_recette_occasion" @("recette_id", "occasion_id") @(
    (SqlText $row.recette_id),
    (SqlInt $row.occasion_id)
  )
}

foreach ($row in Read-CsvFile "FACT_RECETTE_REGIME.csv") {
  Add-Insert $lines "fact_recette_regime" @("recette_id", "regime_id") @(
    (SqlText $row.recette_id),
    (SqlInt $row.regime_id)
  )
}

foreach ($row in Read-CsvFile "FACT_RECETTE_TYPE_PLAT.csv") {
  Add-Insert $lines "fact_recette_type_plat" @("recette_id", "type_plat_id") @(
    (SqlText $row.recette_id),
    (SqlInt $row.type_plat_id)
  )
}

$lines.Add("") | Out-Null
$lines.Add("commit;") | Out-Null

$outputPath = if ([System.IO.Path]::IsPathRooted($Output)) {
  $Output
} else {
  Join-Path (Get-Location) $Output
}

$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputDir)) {
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

Set-Content -LiteralPath $outputPath -Value $lines -Encoding UTF8
Write-Host "Wrote $outputPath"
