# Publishes the portfolio (index.html in this folder) to GitHub Pages at https://aykutaltuntop.com
# Usage: double-click publish_site.bat. Run it again after every update to the site.
# The website gets its own PUBLIC repository (<you>.github.io). Your project repositories are not touched.
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
$domain = 'aykutaltuntop.com'

function Fail($msg) { Write-Host $msg -ForegroundColor Red; Read-Host 'Press Enter to close'; exit 1 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'git is not installed. Install it with:  winget install --id Git.Git' }
if (-not (Get-Command gh  -ErrorAction SilentlyContinue)) { Fail 'GitHub CLI is not installed. Install it with:  winget install --id GitHub.cli' }
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Fail 'GitHub CLI is not logged in. Run:  gh auth login' }
if (-not (Test-Path index.html)) { Fail 'index.html is missing from this folder.' }

$owner = (gh api user --jq .login).Trim()
$repo  = "$owner.github.io"
Set-Content -Path CNAME -Value $domain -NoNewline -Encoding ascii

if (-not (Test-Path .git)) { git init -q; git symbolic-ref HEAD refs/heads/main }
if (-not (git config user.name))  { git config user.name 'Aykut Altuntop' }
if (-not (git config user.email)) { $uid = (gh api user --jq .id).Trim(); git config user.email "$uid+$owner@users.noreply.github.com" }

gh repo view "$owner/$repo" --json name *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Creating the public website repository $owner/$repo" -ForegroundColor Cyan
  gh repo create "$owner/$repo" --public --description "Personal website: https://$domain"
  if ($LASTEXITCODE -ne 0) { Fail 'GitHub did not create the repository. Wait a few minutes and run this again.' }
  Start-Sleep -Seconds 5
}
git remote get-url origin *> $null
if ($LASTEXITCODE -ne 0) { git remote add origin "https://github.com/$owner/$repo.git" }

# keep GitHub's history if it has any, then put this folder's files on top
git fetch -q origin 2> $null
git rev-parse --verify --quiet origin/main *> $null
if ($LASTEXITCODE -eq 0) {
  git merge-base --is-ancestor origin/main HEAD *> $null
  if ($LASTEXITCODE -ne 0) {
    git symbolic-ref HEAD refs/heads/main
    git update-ref refs/heads/main origin/main
    git reset -q --mixed origin/main
  }
}

git add -A
if (git status --porcelain) { git commit -q -m "Update website" }
git push -u origin HEAD:main
if ($LASTEXITCODE -ne 0) { Fail 'Upload failed. Check your internet connection and run this again.' }

# turn on GitHub Pages from the main branch and attach the domain
gh api "repos/$owner/$repo/pages" *> $null
if ($LASTEXITCODE -ne 0) {
  gh api -X POST "repos/$owner/$repo/pages" -f "source[branch]=main" -f "source[path]=/" *> $null
  Start-Sleep -Seconds 3
}
gh api -X PUT "repos/$owner/$repo/pages" -f "cname=$domain" *> $null
gh api -X PUT "repos/$owner/$repo/pages" -F "https_enforced=true" *> $null
if ($LASTEXITCODE -eq 0) { $https = 'on' } else { $https = 'not yet: GitHub is still preparing the certificate, run this again in 30-60 minutes' }

Write-Host "`nDone. Your site: https://$domain" -ForegroundColor Green
Write-Host "HTTPS: $https"
Write-Host 'Changes usually appear within 1-2 minutes.'
Read-Host "`nPress Enter to close"
