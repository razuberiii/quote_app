#  .\script\capture_pages.ps1 -LoginEmail "710006009@qq.com" -LoginPassword "123456" -Locale "zh-CN/en/es-419"
param(
  [string]$BaseUrl = "http://127.0.0.1:3000",
  [string]$LoginEmail = "",
  [string]$LoginPassword = "",
  [string]$Locale = "",
  [string]$OutDir = "",
  [string[]]$SkipPaths = @(
    "/sitemap.xml",
    "/command_palette/search",
    "/customers/shortcut_candidates",
    "/addon_presets/new",
    "/spec_presets/new"
  )
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = "tmp/page_screenshots_manual_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Requires: npm install -D playwright
node -e "require('playwright'); console.log('playwright_ok')" | Out-Null

$routesFile = "tmp/routes_for_screenshots_manual.txt"
$pathsFile = "tmp/screenshot_paths_manual.txt"
$runnerFile = "tmp/capture_pages_runner.js"

rails routes | Out-File -Encoding utf8 $routesFile

$paths = @()
Get-Content $routesFile | ForEach-Object {
  if ($_ -match "^\s*(?:\S+\s+)?GET\s+([^\s]+)") {
    $uri = $matches[1]
    $uri = ($uri -split "\{")[0]
    $uri = $uri -replace "\(\.:format\)", ""

    if ([string]::IsNullOrWhiteSpace($uri)) { return }
    if ($uri -notmatch "^/") { return }
    if ($uri -match ":") { return }
    if ($uri -match "\*") { return }
    if ($uri -match "^/rails") { return }
    if ($uri -in @("/up", "/recede_historical_location", "/resume_historical_location", "/refresh_historical_location")) { return }
    if ($SkipPaths -contains $uri) { return }

    $paths += $uri
  }
}
$paths = $paths | Sort-Object -Unique

# Add dynamic pages (/:id, /:token) from current DB records.
$dynamicRunnerFile = "tmp/dynamic_screenshot_paths.rb"
$dynamicRunnerCode = @'
require "json"

paths = []
company = Company.first

if company
  customer = company.customers.order(:id).first
  if customer
    paths << "/customers/#{customer.id}"
    paths << "/customers/#{customer.id}/edit"
  end

  product = company.products.order(:id).first
  if product
    paths << "/products/#{product.id}"
    paths << "/products/#{product.id}/edit"
  end

  quote = company.quotes.not_archived.order(:id).first
  if quote
    paths << "/quotes/#{quote.id}"
    paths << "/quotes/#{quote.id}/edit"
    paths << "/quotes/#{quote.id}/public_preview"
    paths << "/quotes/#{quote.id}/export/pdf?preview=1"
    paths << "/quotes/#{quote.id}/export/xlsx?preview=1"

    share = company.quote_shares.active.where(quote_id: quote.id).order(created_at: :desc).first
    unless share
      share = company.quote_shares.create!(
        quote: quote,
        token: QuoteShare.generate_token,
        snapshot: QuoteSnapshotBuilder.new(quote).as_json
      )
    end
    paths << "/public/quote_shares/#{share.token}" if share&.token.present?
  end

  user = company.users.order(:id).first
  paths << "/team_members/#{user.id}" if user
end

puts JSON.generate(paths.uniq)
'@
Set-Content -Encoding UTF8 $dynamicRunnerFile $dynamicRunnerCode
$dynamicJson = rails runner $dynamicRunnerFile
if (-not [string]::IsNullOrWhiteSpace($dynamicJson)) {
  $dynamicPaths = @()
  try {
    $dynamicPaths = ConvertFrom-Json $dynamicJson
  } catch {
    $dynamicPaths = @()
  }
  if ($dynamicPaths) {
    foreach ($dp in $dynamicPaths) {
      if ([string]::IsNullOrWhiteSpace($dp)) { continue }
      if ($SkipPaths -contains $dp) { continue }
      $paths += $dp
    }
  }
}

$paths = $paths | Sort-Object -Unique
$paths | Out-File -Encoding utf8 $pathsFile

$runner = @'
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const base = process.env.BASE_URL;
  const outDir = process.env.OUT_DIR;
  const loginEmail = process.env.LOGIN_EMAIL || '';
  const loginPassword = process.env.LOGIN_PASSWORD || '';
  const captureLocale = process.env.CAPTURE_LOCALE || '';
  const pathsFile = process.env.PATHS_FILE;
  const logFile = path.join(outDir, '_capture_log.txt');

  const routes = fs.readFileSync(pathsFile, 'utf8').split(/\r?\n/).map(s => s.trim()).filter(Boolean);
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();

  const log = (line) => fs.appendFileSync(logFile, line + '\n');
  const withLocale = (route) => {
    if (!captureLocale) return route;
    const separator = route.includes('?') ? '&' : '?';
    return `${route}${separator}locale=${encodeURIComponent(captureLocale)}`;
  };
  const targetUrl = (route) => `${base}${withLocale(route)}`;
  log(`Capture start: ${new Date().toISOString()}`);
  log(`Base URL: ${base}`);
  log(`Locale: ${captureLocale || 'default'}`);
  log(`Total candidate pages: ${routes.length}`);

  if (loginEmail && loginPassword) {
    await page.goto(targetUrl('/users/sign_in'), { waitUntil: 'domcontentloaded' });
    await page.fill('input[name="user[email]"]', loginEmail);
    await page.fill('input[name="user[password]"]', loginPassword);
    await Promise.all([
      page.waitForResponse((resp) =>
        resp.url().includes('/users/sign_in') &&
        resp.request().method() === 'POST'
      ),
      page.click('input[type="submit"], button[type="submit"]')
    ]);
    await page.waitForTimeout(800);

    // Authoritative auth check: try opening dashboard after sign-in.
    await page.goto(targetUrl('/dashboard'), { waitUntil: 'domcontentloaded', timeout: 30000 });
    const currentPath = new URL(page.url()).pathname;
    const loginFormStillVisible =
      (await page.locator('input[name="user[email]"]').count()) > 0 &&
      (await page.locator('input[name="user[password]"]').count()) > 0;
    if (currentPath === '/users/sign_in' || loginFormStillVisible) {
      const loginError = await page.locator('.alert, .flash, .error, .notice').first().textContent().catch(() => '');
      throw new Error(`Login failed. Current path: ${currentPath}. Message: ${loginError || 'n/a'}`);
    }

    log('Login: success');
  } else {
    log('Login: skipped (no credentials provided)');
  }

  let ok = 0;
  let fail = 0;
  for (let i = 0; i < routes.length; i++) {
    const p = routes[i];
    const idx = String(i + 1).padStart(3, '0');
    let slug = p === '/' ? 'home' : p.replace(/^\//, '').replace(/[^a-zA-Z0-9\-_\/]/g, '').replace(/\//g, '__');
    if (!slug) slug = 'page';
    const file = path.join(outDir, `${idx}_${slug}.png`);

    try {
      const response = await page.goto(targetUrl(p), { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForTimeout(450);

      if (!loginEmail || !loginPassword) {
        const currentPath = new URL(page.url()).pathname;
        const loginFormVisible =
          (await page.locator('input[name="user[email]"]').count()) > 0 &&
          (await page.locator('input[name="user[password]"]').count()) > 0;
        const bodyTextForAuth = await page.locator('body').innerText().catch(() => '');
        const authPromptDetected = /You need to sign in or sign up before continuing|请先登录|请登录/i.test(bodyTextForAuth);
        if (currentPath === '/users/sign_in' || loginFormVisible || authPromptDetected) {
          log(`[SKIP-AUTH] ${p} -> redirected to/sign-in required`);
          continue;
        }
      }

      const contentType = (response && response.headers()['content-type']) || '';
      if (/application\/pdf|application\/vnd\.openxmlformats-officedocument/i.test(contentType)) {
        log(`[SKIP-NON-HTML] ${p} (${contentType})`);
        continue;
      }
      const bodyText = await page.locator('body').innerText().catch(() => '');
      if (/Unknown action|ActionController::RoutingError|No route matches/i.test(bodyText)) {
        log(`[SKIP-ERROR-PAGE] ${p}`);
        continue;
      }
      await page.screenshot({ path: file, fullPage: true });
      log(`[OK] ${p} -> ${path.basename(file)}`);
      ok++;
    } catch (e) {
      log(`[FAIL] ${p} -> ${e.message}`);
      fail++;
    }
  }

  log(`Capture end: ${new Date().toISOString()}`);
  log(`Summary: ok=${ok} fail=${fail}`);
  await browser.close();
  console.log(`Summary: ok=${ok} fail=${fail}`);
})();
'@

Set-Content -Encoding UTF8 $runnerFile $runner

$env:BASE_URL = $BaseUrl
$env:OUT_DIR = (Resolve-Path $OutDir).Path
$env:LOGIN_EMAIL = $LoginEmail
$env:LOGIN_PASSWORD = $LoginPassword
$env:CAPTURE_LOCALE = $Locale
$env:PATHS_FILE = (Resolve-Path $pathsFile).Path

node $runnerFile

Write-Output "Saved screenshots to: $OutDir"
Write-Output "Log file: $OutDir/_capture_log.txt"
