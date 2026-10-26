$ErrorActionPreference = 'Stop'
$project = (Get-Location).Path
$dashboard = Join-Path $project 'lib/features/dashboard/dashboard_overview.dart'
$page = Join-Path $project 'lib/features/dashboard/dashboard_page.dart'
$transactions = Join-Path $project 'lib/features/transactions/transactions_page.dart'
foreach ($path in @($dashboard, $page, $transactions)) {
  if (-not (Test-Path $path)) { throw "Ejecuta este script desde la raiz del proyecto Flutter. Falta: $path" }
}
if (-not (Test-Path (Join-Path $project 'lib/features/receivable_loans/receivable_loans_page.dart'))) {
  throw 'Primero combina la carpeta lib del paquete con la carpeta lib de tu proyecto.'
}
$changes = @{}
$text = [IO.File]::ReadAllText($dashboard)
$pattern = "(?s)_dashboardRows\(\s*'transactions'\s*,.*?user\.id\s*,?\s*\)"
if ($text -match $pattern) {
  $text = [regex]::Replace($text, $pattern, 'loadUserTransactions(user.id)', 1)
} elseif ($text -notmatch 'loadUserTransactions\(user\.id\)') {
  throw 'No se pudo identificar la carga de movimientos del dashboard. No se modifico ningun archivo.'
}
if ($text -notmatch "import '../../data/transaction_repository.dart';") {
  $text = "import '../../data/transaction_repository.dart';`n" + $text
}
$changes[$dashboard] = $text

$text = [IO.File]::ReadAllText($page)
if ($text -notmatch 'ReceivableLoansDashboard\(') {
  $pattern = 'DashboardQuickActions\(\s*onOpen:\s*openTarget\s*,?\s*\),'
  if ($text -notmatch $pattern) { throw 'No se encontro DashboardQuickActions. No se modifico ningun archivo.' }
  $block = @'

            if (!loading && error == null && current != null) ...[
              const SizedBox(height: 20),
              ReceivableLoansDashboard(
                refreshToken: current.loadedAt,
                onChanged: () { loadData(); },
              ),
            ],
'@
  $match = [regex]::Match($text, $pattern)
  $text = $text.Insert($match.Index + $match.Length, $block)
}
if ($text -notmatch "import '../receivable_loans/receivable_loans_dashboard.dart';") {
  $text = "import '../receivable_loans/receivable_loans_dashboard.dart';`n" + $text
}
$changes[$page] = $text

$sourcePattern = "'credit_card_payment'\s*,\s*'debt_payment'(?!\s*,\s*'receivable_loan')"
$files = @('transactions_page.dart', 'transaction_filter.dart', 'transaction_tile.dart', 'transaction_details_dialog.dart')
foreach ($name in $files) {
  $path = Join-Path $project "lib/features/transactions/$name"
  if (-not (Test-Path $path)) { continue }
  $text = [IO.File]::ReadAllText($path)
  if ($name -eq 'transactions_page.dart' -and $text -notmatch $sourcePattern -and $text -notmatch "'receivable_loan'") {
    throw 'La proteccion de movimientos vinculados tiene otra estructura. No se modifico ningun archivo.'
  }
  $updated = [regex]::Replace($text, $sourcePattern, "'credit_card_payment', 'debt_payment', 'receivable_loan'")
  if ($updated -ne $text) { $changes[$path] = $updated }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $project "respaldo-prestamos-$stamp"
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($entry in $changes.GetEnumerator()) {
  $relative = $entry.Key.Substring($project.Length).TrimStart([char[]]'\/')
  $destination = Join-Path $backup $relative
  New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
  Copy-Item -LiteralPath $entry.Key -Destination $destination
  [IO.File]::WriteAllText($entry.Key, $entry.Value, $utf8)
}
Write-Host 'Integracion completada. Ejecuta flutter analyze y las pruebas incluidas.' -ForegroundColor Green
Write-Host "Respaldo de archivos integrados: $backup"
