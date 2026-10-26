param([string]$ProjectRoot = $PSScriptRoot)
$ErrorActionPreference='Stop'
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot)
$path=Join-Path $ProjectRoot 'pubspec.yaml'
if(!(Test-Path $path)){throw 'Copia este script a la raiz del proyecto, junto a pubspec.yaml.'}
foreach($name in @('DejaVuSans.ttf','DejaVuSans-Bold.ttf')){
 if(!(Test-Path (Join-Path $ProjectRoot "assets/fonts/$name"))){throw 'Copia primero la carpeta assets del paquete al proyecto.'}
}
$backup=Join-Path $ProjectRoot ('reportes_backup/pubspec.'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.yaml')
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup)|Out-Null
Copy-Item -LiteralPath $path -Destination $backup
Push-Location $ProjectRoot
try{
 & flutter pub add 'excel:4.0.6' 'pdf:3.12.0' 'file_saver:0.3.1'
 if($LASTEXITCODE -ne 0){throw 'No se pudieron resolver las dependencias. Revisa la salida de flutter pub add.'}
}finally{Pop-Location}
$yaml=[IO.File]::ReadAllText($path)
if($yaml -notmatch '(?m)^\s+-\s+assets/fonts/\s*(?:#.*)?$'){
 $header=[regex]::Match($yaml,'(?m)^flutter:[ \t]*(?:#.*)?\r?$')
 if(!$header.Success){throw 'No se encontro la seccion flutter: en pubspec.yaml.'}
 $tail=$yaml.Substring($header.Index+$header.Length)
 $next=[regex]::Match($tail,'(?m)^[A-Za-z_][A-Za-z0-9_]*[ \t]*:')
 $end=$yaml.Length;if($next.Success){$end=$header.Index+$header.Length+$next.Index}
 $block=$yaml.Substring($header.Index,$end-$header.Index)
 if($block -match '(?m)^  assets:[ \t]*\['){throw 'Agrega assets/fonts/ a la lista assets en linea de pubspec.yaml.'}
 $assets=[regex]::Match($block,'(?m)^  assets:[ \t]*(?:#.*)?\r?$')
 if($assets.Success){$offset=$assets.Index+$assets.Length;$block=$block.Substring(0,$offset).TrimEnd([char[]]"`r`n")+"`r`n    - assets/fonts/"+$block.Substring($offset)}
 else{$offset=$header.Length;$block=$block.Substring(0,$offset).TrimEnd([char[]]"`r`n")+"`r`n  assets:`r`n    - assets/fonts/"+$block.Substring($offset)}
 $yaml=$yaml.Substring(0,$header.Index)+$block+$yaml.Substring($end)
 [IO.File]::WriteAllText($path,$yaml,(New-Object System.Text.UTF8Encoding($false)))
}
# El dialogo Guardar de macOS necesita acceso al archivo elegido por el usuario.
foreach($name in @('DebugProfile.entitlements','Release.entitlements')){
 $entitlement=Join-Path $ProjectRoot "macos/Runner/$name"
 if(Test-Path $entitlement){
  $doc=New-Object System.Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.XmlResolver=$null
  $doc.LoadXml([IO.File]::ReadAllText($entitlement));$dict=$doc.SelectSingleNode('/plist/dict')
  if($null -eq $dict){throw "Entitlements no valido: $name"}
  $key=$dict.SelectSingleNode("key[text()='com.apple.security.files.user-selected.read-write']")
  if($null -eq $key){$key=$doc.CreateElement('key');$key.InnerText='com.apple.security.files.user-selected.read-write';[void]$dict.AppendChild($key);[void]$dict.AppendChild($doc.CreateElement('true'))}
  else{$value=$key.SelectSingleNode('following-sibling::*[1]');[void]$dict.ReplaceChild($doc.CreateElement('true'),$value)}
  $copy=Join-Path $ProjectRoot ("reportes_backup/"+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+"-$name")
  Copy-Item -LiteralPath $entitlement -Destination $copy
  [IO.File]::WriteAllText($entitlement,$doc.OuterXml,(New-Object System.Text.UTF8Encoding($false)))
 }
}
Write-Host 'Reportes configurados. Ejecuta flutter pub get, flutter analyze y recompila.' -ForegroundColor Green
