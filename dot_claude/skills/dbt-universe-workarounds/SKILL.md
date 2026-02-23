---
name: dbt-universe-workarounds
description: Workarounds for stocks missing from investable universe due to stale dbt materialisation. Tracks stocks needing rebuild.
---

# dbt Universe Workarounds

## Problem

Some stocks have raw data in Snowflake but are missing from canonical views (WEEKLY_OHLCV, SCREEN_WEEKLY) because:

1. **Stale materialised tables** - DM country flags not refreshed after config changes
2. **Emerging market exclusion** - Stock's country not in `msci_dm_countries` list
3. **New listings** - Recently added stocks not yet picked up by rebuild

## Stocks Pending Rebuild

See `pending_rebuilds.json` in this skill directory for current list.

**Current pending:**

| Ticker | Issue | Resolution | Ticket |
|--------|-------|------------|--------|
| KOG-NO | Norway flagged as non-DM in stale table | dbt rebuild | quinlan-udkf |
| TSM-US | Taiwan = Emerging Market | Add TW to msci_dm_countries or use 2330-TW | N/A |

## Checking If a Stock Needs Rebuild

### Step 1: Check if raw data exists

```sql
SELECT COUNT(*) as days, MIN(TRADE_DATE), MAX(TRADE_DATE)
FROM QUINLAN.STG_SPG.PRICES_RAW
WHERE TICKER_REGION = '{TICKER}';
```

### Step 2: Check if weekly data exists

```sql
SELECT COUNT(*) as weeks
FROM QUINLAN.INT_SPG.WEEKLY_OHLCV
WHERE TICKER_REGION = '{TICKER}';
```

If raw data exists but weekly data is empty, the stock needs a rebuild or workaround.

### Step 3: Check DM flag in materialised table

```sql
SELECT TICKER_REGION, LISTING_COUNTRY, IS_DEVELOPED_MARKET, IS_INVESTABLE
FROM QUINLAN.INT_SPG.INVESTABLE_UNIVERSE_WEEKLY_FLAGS_MAT
WHERE TICKER_REGION = '{TICKER}'
LIMIT 1;
```

### Step 4: Check if country is in config

Look in `warehouse/dbt_project.yml` for `msci_dm_countries` list.

## Workarounds

### Option 1: Use Raw Data Directly (temporary)

For regime charts or analysis, query raw prices instead of canonical views:

```sql
SELECT
  TICKER_REGION,
  TRADE_DATE,
  ADJ_CLOSE_USD,
  VOLUME
FROM QUINLAN.STG_SPG.PRICES_RAW
WHERE TICKER_REGION = '{TICKER}'
  AND TRADE_DATE >= DATEADD('year', -2, CURRENT_DATE())
ORDER BY TRADE_DATE;
```

Note: Raw data lacks peer-relative calculations.

### Option 2: Use Alternative Listing

Some stocks have multiple listings. If the ADR is excluded, use the primary:

| ADR Ticker | Primary Listing | Notes |
|------------|----------------|-------|
| TSM-US | 2330-TW | Taiwan Semi - TW is EM so excluded |

### Option 3: Request dbt Rebuild

If the stock should be in the universe (country is in DM list, meets criteria):

1. Create a beads ticket linking to `quinlan-sn35` (permissions)
2. Add to `pending_rebuilds.json`
3. Rebuild command (requires elevated permissions):

```bash
cd warehouse && uv run dbt build --select int_investable_universe_weekly_flags+ --target prod
```

## Rebuild Command Reference

**Full investable universe rebuild:**
```bash
uv run dbt build --select int_investable_universe_weekly_flags+ --target prod --project-dir /home/jeremylang/projects/quinlan/warehouse
```

**Check source freshness first:**
```bash
uv run dbt source freshness --target prod --project-dir /home/jeremylang/projects/quinlan/warehouse
```

## Adding Stocks to Pending List

Update `pending_rebuilds.json`:

```json
{
  "pending_rebuilds": [
    {
      "ticker": "KOG-NO",
      "issue": "Norway flagged as non-DM in stale materialised table",
      "resolution": "dbt rebuild int_investable_universe_weekly_flags+",
      "ticket": "quinlan-udkf",
      "added": "2026-01-18"
    }
  ],
  "excluded_by_design": [
    {
      "ticker": "TSM-US",
      "issue": "Taiwan = Emerging Market",
      "workaround": "Use 2330-TW if available, or query raw data",
      "added": "2026-01-18"
    }
  ]
}
```

## Related

- `quinlan-sn35`: dbt build permissions (blocker)
- `quinlan-udkf`: Norway rebuild ticket
- `ticker-disambiguation` skill: For duplicate ticker issues
