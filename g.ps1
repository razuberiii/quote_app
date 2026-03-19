$ErrorActionPreference = "Stop"

git add -A

if ((git status --porcelain).Length -eq 0) {
  Write-Host "No changes to commit."
  exit 0
}

$msg = Get-Date -Format "yyyy-MM-dd"
git commit -m $msg
git push
