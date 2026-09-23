param([switch]$Strict)

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src\luatool'
$out = Join-Path $root 'umbrella-lua\scripts\luatool.exe'
$csc = @("$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe", "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) { 'ERROR csc.exe from .NET Framework 4 not found'; exit 1 }

$files = Get-ChildItem $src -Filter *.cs | ForEach-Object { $_.FullName }
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
& $csc /nologo /optimize+ /target:exe /platform:anycpu "/out:$out" "/resource:$src\assets\qlocalizer.lua,qlocalizer.lua" "/resource:$src\assets\template.lua,template.lua" $files
if ($LASTEXITCODE -ne 0) { 'BUILD FAILED'; exit 1 }
"BUILT $out ($([math]::Round((Get-Item $out).Length / 1KB)) KB)"
$env:UMBRELLA_LUA_NO_UPDATE = '1'
$num = (& $out version | Select-Object -First 1) -replace '^umbrella-lua ', ''
$readme = [IO.File]::ReadAllText((Join-Path $root 'README.md'))
if ($readme.Contains("**$num**")) { "VERSION $num" }
else {
    "WARN README.md does not show version **$num**, update it"
    if ($Strict) { exit 1 }
}
