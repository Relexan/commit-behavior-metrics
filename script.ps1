param(
  [Parameter(Mandatory=$true)][string]$Repo,
  [Parameter(Mandatory=$true)][string]$Hash,
  [string[]]$Files,
  [string]$IncludeRegex
)

Set-Location $Repo
$env:GIT_PAGER = "cat"
$env:PAGER = "cat"

if (-not $Files -or $Files.Count -eq 0) {
  $Files = git show --name-only --pretty="" $Hash --
  $Files = $Files | Where-Object { $_ -and $_.Trim() -ne "" }
  if ($IncludeRegex) {
    $Files = $Files | Where-Object { $_ -match $IncludeRegex }
  }
}

$CF = $Files.Count

# -------------------------------
# CAU
# -------------------------------
$splitPaths = @(
  $Files | ForEach-Object { ,(($_ -replace '\\','/').Split('/')) }
)

if ($splitPaths.Count -le 1) {
  $CAU = $CF
}
else {
  $minLen = ($splitPaths | ForEach-Object { $_.Count } | Measure-Object -Minimum).Minimum
  $prefixLen = 0

  for ($i = 0; $i -lt $minLen; $i++) {
    $seg = $splitPaths[0][$i]
    $allSame = $true
    foreach ($p in $splitPaths) {
      if ($p[$i] -ne $seg) {
        $allSame = $false
        break
      }
    }
    if ($allSame) {
      $prefixLen++
    }
    else {
      break
    }
  }

  $units = foreach ($p in $splitPaths) {
    if ($prefixLen -lt $p.Count) { $p[$prefixLen] } else { $p[-1] }
  }

  $CAU = ($units | Sort-Object -Unique).Count
}

# -------------------------------
# Insertions / Deletions / LCC
# -------------------------------
$numstat = git show --numstat --pretty="" $Hash -- $Files
$ins = 0
$del = 0

foreach ($row in $numstat) {
  $p = $row -split "`t"
  if ($p.Length -ge 2 -and $p[0] -match '^\d+$' -and $p[1] -match '^\d+$') {
    $ins += [int]$p[0]
    $del += [int]$p[1]
  }
}

$LCC = $ins + $del

# Baseline for relative change size
$baseline = 0
foreach ($f in $Files) {
  $c = git show "$Hash^:$f" 2>$null
  if ($LASTEXITCODE -eq 0) {
    $baseline += ($c | Measure-Object -Line).Lines
  }
}

$NormalizedLCC = if ($baseline -gt 0) {
  [math]::Round($LCC / $baseline, 3)
}
else {
  $null
}

# -------------------------------
# CM
# -------------------------------
$methodRegex = '^\s*(?:public|private|protected|internal)\s+(?:static\s+)?(?:async\s+)?[\w<>\[\],\s]+\s+([A-Za-z_]\w*)\s*\('
$changedMethods = New-Object 'System.Collections.Generic.HashSet[string]'

# -------------------------------
# Secondary proxy metrics
# -------------------------------
$LOCG = 0
$APC = 0
$CondChurn = 0

# -------------------------------
# Cyclomatic Complexity (CC)
# -------------------------------
$CC = 0
$addedCCForMethod = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($f in $Files) {

  $diff = git show $Hash -U0 --function-context -- $f
  $currentMethod = $null
  $hunkHasChange = $false

  foreach ($line in $diff) {

    if ($line -match '^\@\@') {
      if ($hunkHasChange -and $currentMethod) {
        [void]$changedMethods.Add($currentMethod)
        if (-not $addedCCForMethod.Contains($currentMethod)) {
          $CC += 1   # Base CC per modified method
          $addedCCForMethod.Add($currentMethod) | Out-Null
        }
      }
      $hunkHasChange = $false
      continue
    }

    # Method detection
    $m = [regex]::Match($line, $methodRegex)
    if ($m.Success) {
      $currentMethod = $m.Groups[1].Value
    }

    # Diff line detection
    if (($line -match '^[\+\-]') -and
        ($line -notmatch '^\+\+\+') -and
        ($line -notmatch '^\-\-\-')) {

      $hunkHasChange = $true

      # LOCG: &&, ||, !
      if ($line -match '(\&\&|\|\||(?<!\!)\!)') {
        $LOCG++
      }

      # APC: ==, !=, <, >, <=, >=, Any(), All(), Contains(), None()
      if ($line -match '(==|!=|<=|>=|<|>|Any\(|All\(|Contains\(|None\()') {
        $APC++
      }

      # CondChurn: if, else, switch, case, ternary ?:
      if ($line -match '^[\+\-].*((\bif\b)|(\belse\b)|(\bswitch\b)|(\bcase\b)|\?:)') {
        $CondChurn++
      }

      # Cyclomatic Complexity proxy: if, else if, for, foreach, while, switch, case, ternary
      if ($line -match '(\bif\b|\belse if\b|\bfor\b|\bforeach\b|\bwhile\b|\bswitch\b|\bcase\b|\?:)') {
        $CC++
      }
    }
  }

  if ($hunkHasChange -and $currentMethod) {
    [void]$changedMethods.Add($currentMethod)
    if (-not $addedCCForMethod.Contains($currentMethod)) {
      $CC += 1
      $addedCCForMethod.Add($currentMethod) | Out-Null
    }
  }
}

$CM = $changedMethods.Count

# -------------------------------
# Normalized Metrics (divide by LCC)
# -------------------------------
function Get-NormalizedValue {
  param(
    [double]$MetricValue,
    [double]$LCCValue
  )

  if ($LCCValue -gt 0) {
    return [math]::Round($MetricValue / $LCCValue, 3)
  }
  else {
    return $null
  }
}

$NormalizedCF = Get-NormalizedValue -MetricValue $CF -LCCValue $LCC
$NormalizedCAU = Get-NormalizedValue -MetricValue $CAU -LCCValue $LCC
$NormalizedCM = Get-NormalizedValue -MetricValue $CM -LCCValue $LCC
$NormalizedCC = Get-NormalizedValue -MetricValue $CC -LCCValue $LCC
$NormalizedLOCG = Get-NormalizedValue -MetricValue $LOCG -LCCValue $LCC
$NormalizedAPC = Get-NormalizedValue -MetricValue $APC -LCCValue $LCC
$NormalizedCondChurn = Get-NormalizedValue -MetricValue $CondChurn -LCCValue $LCC

# -------------------------------
# Output
# -------------------------------
[pscustomobject]@{
  Repo                  = $Repo
  Hash                  = $Hash

  CF                    = $CF
  CAU                   = $CAU
  Insertions            = $ins
  Deletions             = $del
  LCC                   = $LCC
  CM                    = $CM
  CC                    = $CC
  LOCG                  = $LOCG
  APC                   = $APC
  CondChurn             = $CondChurn

  NormalizedLCC         = $NormalizedLCC
  NormalizedCF          = $NormalizedCF
  NormalizedCAU         = $NormalizedCAU
  NormalizedCM          = $NormalizedCM
  NormalizedCC          = $NormalizedCC
  NormalizedLOCG        = $NormalizedLOCG
  NormalizedAPC         = $NormalizedAPC
  NormalizedCondChurn   = $NormalizedCondChurn

  Files                 = ($Files -join ", ")
} | Format-List