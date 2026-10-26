$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$dashboard = Join-Path $root 'lib/features/dashboard/dashboard_overview.dart'
$history = Join-Path $root 'lib/features/credit_cards/credit_card_movements_page.dart'
if (-not (Test-Path $dashboard)) { throw 'Ejecuta este script desde la raiz de tu proyecto Flutter.' }
$changes = @{}
$text = [IO.File]::ReadAllText($dashboard)
$pattern = "(?s)_dashboardRows\(\s*'credit_card_transactions'\s*,.*?user\.id\s*,?\s*\)"
$match = [regex]::Match($text, $pattern)
if (-not $match.Success) { throw 'No se reconocio la consulta de tarjetas del dashboard. No se modifico ningun archivo.' }
if ($match.Value -notmatch 'is_receivable_funding') {
  $block = $match.Value.Replace('is_voided', 'is_voided, is_receivable_funding')
  if ($block -eq $match.Value) { throw 'No se encontro is_voided en la consulta. No se modifico ningun archivo.' }
  $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, $block)
}
$condition = "if\s*\(\s*effect\s*!=\s*null\s*&&\s*type\s*!=\s*'payment'\s*\)"
if ($text -match $condition) {
  $text = [regex]::Replace($text, $condition,
    "if (effect != null && type != 'payment' && tx['is_receivable_funding'] != true)")
} elseif ($text -notmatch "tx\['is_receivable_funding'\]\s*!=\s*true") {
  throw 'No se reconocio el calculo de gastos del dashboard. No se modifico ningun archivo.'
}
$changes[$dashboard] = $text

if (Test-Path $history) {
  $text = [IO.File]::ReadAllText($history)
  if ($text -notmatch 'is_voided, is_receivable_funding') {
    $text = $text.Replace('category_id, is_voided,', 'category_id, is_voided, is_receivable_funding,')
  }
  $guard = "if \(loading \|\| saving \|\|\s*!\['purchase'"
  $text = [regex]::Replace($text, $guard,
    "if (loading || saving || tx['is_receivable_funding'] == true ||`n        !['purchase'")
  $text = $text.Replace("if (['purchase', 'interest', 'fee', 'refund'].contains(type))",
    "if (tx['is_receivable_funding'] != true && ['purchase', 'interest', 'fee', 'refund'].contains(type))")
  if ($text -notmatch 'Cargo vinculado a un prestamo') {
    $text = $text.Replace("if (type == 'adjustment')",
      "if (tx['is_receivable_funding'] == true)`n        const Text('Cargo vinculado a un prestamo. Administralo desde Prestamos por cobrar.'),`n      if (type == 'adjustment')")
  }
  $changes[$history] = $text
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $root "respaldo-origen-tarjetas-$stamp"
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($entry in $changes.GetEnumerator()) {
  $relative = $entry.Key.Substring($root.Length).TrimStart([char[]]'\/')
  $destination = Join-Path $backup $relative
  New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
  Copy-Item -LiteralPath $entry.Key -Destination $destination
  [IO.File]::WriteAllText($entry.Key, $entry.Value, $utf8)
}
Write-Host 'Integracion de tarjetas completada. Ejecuta flutter analyze y las pruebas.' -ForegroundColor Green
Write-Host "Respaldo: $backup"
