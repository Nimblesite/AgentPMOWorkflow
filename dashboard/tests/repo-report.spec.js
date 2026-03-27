// @ts-check
const { test, expect } = require('@playwright/test');
const path = require('path');

const reportPath = 'file://' + path.resolve(__dirname, '..', 'repo-report.html');

test.beforeEach(async ({ page }) => {
  await page.goto(reportPath);
});

test('page loads and shows h1 title', async ({ page }) => {
  await expect(page.locator('h1')).toHaveText('Repo Report');
});

test('all 3 tab buttons exist', async ({ page }) => {
  const tabs = page.locator('.tab-btn');
  await expect(tabs).toHaveCount(3);
  await expect(tabs.nth(0)).toContainText('Repo Status');
  await expect(tabs.nth(1)).toContainText('Community PRs');
  await expect(tabs.nth(2)).toContainText('Community Issues');
});

test('Repo Status tab is active by default', async ({ page }) => {
  const firstTab = page.locator('.tab-btn').nth(0);
  await expect(firstTab).toHaveClass(/active/);

  const repoContent = page.locator('#tab-repos');
  await expect(repoContent).toHaveClass(/active/);

  const prContent = page.locator('#tab-prs');
  await expect(prContent).not.toHaveClass(/active/);

  const issuesContent = page.locator('#tab-issues');
  await expect(issuesContent).not.toHaveClass(/active/);
});

test('clicking Community PRs tab shows PR content and hides others', async ({ page }) => {
  const prTab = page.locator('.tab-btn[data-tab="tab-prs"]');
  await prTab.click();

  await expect(prTab).toHaveClass(/active/);
  await expect(page.locator('#tab-prs')).toHaveClass(/active/);
  await expect(page.locator('#tab-repos')).not.toHaveClass(/active/);
  await expect(page.locator('#tab-issues')).not.toHaveClass(/active/);
});

test('clicking Community Issues tab shows issues content and hides others', async ({ page }) => {
  const issuesTab = page.locator('.tab-btn[data-tab="tab-issues"]');
  await issuesTab.click();

  await expect(issuesTab).toHaveClass(/active/);
  await expect(page.locator('#tab-issues')).toHaveClass(/active/);
  await expect(page.locator('#tab-repos')).not.toHaveClass(/active/);
  await expect(page.locator('#tab-prs')).not.toHaveClass(/active/);
});

test('can switch between all tabs', async ({ page }) => {
  const repoTab = page.locator('.tab-btn[data-tab="tab-repos"]');
  const prTab = page.locator('.tab-btn[data-tab="tab-prs"]');
  const issuesTab = page.locator('.tab-btn[data-tab="tab-issues"]');

  // Go to PRs
  await prTab.click();
  await expect(page.locator('#tab-prs')).toHaveClass(/active/);

  // Go to Issues
  await issuesTab.click();
  await expect(page.locator('#tab-issues')).toHaveClass(/active/);

  // Go back to Repos
  await repoTab.click();
  await expect(page.locator('#tab-repos')).toHaveClass(/active/);
});

test('Repo Status tab contains a table with expected columns', async ({ page }) => {
  const repoTab = page.locator('#tab-repos');
  await expect(repoTab).toHaveClass(/active/);

  const headers = repoTab.locator('th');
  await expect(headers).toHaveCount(11);
  await expect(headers.nth(0)).toHaveText('Repository');
  await expect(headers.nth(1)).toHaveText('Uncommitted');
  await expect(headers.nth(2)).toHaveText('Last Commit');
  await expect(headers.nth(3)).toHaveText('Branch');
  await expect(headers.nth(4)).toHaveText('PR Branch');
  await expect(headers.nth(5)).toHaveText('Push Status');
  await expect(headers.nth(6)).toHaveText('Open PR');
  await expect(headers.nth(7)).toHaveText('CI');
  await expect(headers.nth(8)).toHaveText('CI Date');
  await expect(headers.nth(9)).toHaveText('CI Error');
  await expect(headers.nth(10)).toHaveText('Release');
});

test('Repo Status tab has data rows', async ({ page }) => {
  const rows = page.locator('#tab-repos tbody tr');
  const count = await rows.count();
  expect(count).toBeGreaterThan(0);
});

test('Community PRs tab has expected columns when it has data or shows empty message', async ({ page }) => {
  const prTab = page.locator('.tab-btn[data-tab="tab-prs"]');
  await prTab.click();

  const content = page.locator('#tab-prs');
  const hasTable = await content.locator('table').count();
  const hasEmpty = await content.locator('p').count();

  expect(hasTable + hasEmpty).toBeGreaterThan(0);

  if (hasTable > 0) {
    const headers = content.locator('th');
    await expect(headers.nth(0)).toHaveText('#');
    await expect(headers.nth(1)).toHaveText('Repository');
    await expect(headers.nth(2)).toHaveText('Title');
    await expect(headers.nth(3)).toHaveText('Author');
    await expect(headers.nth(4)).toHaveText('Created');
  } else {
    await expect(content.locator('p')).toContainText('No community PRs found');
  }
});

test('Community Issues tab has expected columns when it has data or shows empty message', async ({ page }) => {
  const issuesTab = page.locator('.tab-btn[data-tab="tab-issues"]');
  await issuesTab.click();

  const content = page.locator('#tab-issues');
  const hasTable = await content.locator('table').count();
  const hasEmpty = await content.locator('p').count();

  expect(hasTable + hasEmpty).toBeGreaterThan(0);

  if (hasTable > 0) {
    const headers = content.locator('th');
    await expect(headers.nth(0)).toHaveText('#');
    await expect(headers.nth(1)).toHaveText('Repository');
    await expect(headers.nth(2)).toHaveText('Title');
    await expect(headers.nth(3)).toHaveText('Author');
    await expect(headers.nth(4)).toHaveText('Created');
  } else {
    await expect(content.locator('p')).toContainText('No community issues found');
  }
});

test('tab counts in button labels match actual row counts', async ({ page }) => {
  const prTabBtn = page.locator('.tab-btn[data-tab="tab-prs"]');
  const prBtnText = await prTabBtn.textContent();
  const prCountMatch = prBtnText.match(/\((\d+)\)/);
  const prCount = prCountMatch ? parseInt(prCountMatch[1]) : 0;

  const issuesTabBtn = page.locator('.tab-btn[data-tab="tab-issues"]');
  const issuesBtnText = await issuesTabBtn.textContent();
  const issuesCountMatch = issuesBtnText.match(/\((\d+)\)/);
  const issuesCount = issuesCountMatch ? parseInt(issuesCountMatch[1]) : 0;

  // Click PRs tab and count rows
  await prTabBtn.click();
  const prRows = page.locator('#tab-prs tbody tr');
  const actualPrRows = await prRows.count();

  if (prCount > 0) {
    expect(actualPrRows).toBe(prCount);
  } else {
    const emptyMsg = page.locator('#tab-prs p');
    await expect(emptyMsg).toBeVisible();
  }

  // Click Issues tab and count rows
  await issuesTabBtn.click();
  const issueRows = page.locator('#tab-issues tbody tr');
  const actualIssueRows = await issueRows.count();

  if (issuesCount > 0) {
    expect(actualIssueRows).toBe(issuesCount);
  } else {
    const emptyMsg = page.locator('#tab-issues p');
    await expect(emptyMsg).toBeVisible();
  }
});

test('PR table links open in new tab', async ({ page }) => {
  const prTab = page.locator('.tab-btn[data-tab="tab-prs"]');
  await prTab.click();

  const prContent = page.locator('#tab-prs');
  const hasTable = await prContent.locator('table').count();

  if (hasTable > 0) {
    const firstLink = prContent.locator('tbody tr').first().locator('a').first();
    await expect(firstLink).toHaveAttribute('target', '_blank');
    const href = await firstLink.getAttribute('href');
    expect(href).toContain('github.com');
  }
});

test('Issues table links open in new tab', async ({ page }) => {
  const issuesTab = page.locator('.tab-btn[data-tab="tab-issues"]');
  await issuesTab.click();

  const issuesContent = page.locator('#tab-issues');
  const hasTable = await issuesContent.locator('table').count();

  if (hasTable > 0) {
    const firstLink = issuesContent.locator('tbody tr').first().locator('a').first();
    await expect(firstLink).toHaveAttribute('target', '_blank');
    const href = await firstLink.getAttribute('href');
    expect(href).toContain('github.com');
  }
});

test('meta line shows generation date and repo count', async ({ page }) => {
  const meta = page.locator('.meta');
  await expect(meta).toContainText('Generated:');
  await expect(meta).toContainText('Repos scanned:');
});

test('mobile viewport - all tabs visible and clickable', async ({ page, isMobile }) => {
  // Ensure tabs are visible on mobile
  const tabs = page.locator('.tab-btn');
  await expect(tabs).toHaveCount(3);

  for (let i = 0; i < 3; i++) {
    await expect(tabs.nth(i)).toBeVisible();
  }

  // Click PRs tab on mobile
  await tabs.nth(1).click();
  await expect(page.locator('#tab-prs')).toHaveClass(/active/);

  // Click Issues tab on mobile
  await tabs.nth(2).click();
  await expect(page.locator('#tab-issues')).toHaveClass(/active/);

  // Click Repos tab on mobile
  await tabs.nth(0).click();
  await expect(page.locator('#tab-repos')).toHaveClass(/active/);
});
