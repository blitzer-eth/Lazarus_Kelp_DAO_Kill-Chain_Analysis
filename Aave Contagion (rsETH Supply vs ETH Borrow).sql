
-- ============================================================
-- Query 2: AAVE CONTAGION
-- Dual-axis: Stolen rsETH supplied to Aave v3 vs ETH/WETH borrowed
-- Time window: 2026-04-16 to 2026-04-21 (pre/post-hack context)
-- ============================================================

WITH

-- Step 1: rsETH supply events into Aave v3 on Ethereum
aave_rseth_supply AS (
    SELECT
        DATE_TRUNC('hour', block_time)                              AS hour_bucket,
        SUM(amount)                                                 AS rseth_supplied,
        SUM(amount_usd)                                             AS rseth_supplied_usd,
        COUNT(*)                                                    AS supply_tx_count
    FROM lending.supply
    WHERE blockchain   = 'ethereum'
      AND project      = 'aave'
      AND symbol       = 'rsETH'
      AND block_month >= TIMESTAMP '2026-04-01'
      AND block_time  >= TIMESTAMP '2026-04-16'
      AND block_time  <  TIMESTAMP '2026-04-22'
    GROUP BY 1
),

-- Step 2: ETH + WETH borrowed from Aave v3 on Ethereum (spike = attacker borrowing)
aave_eth_borrow AS (
    SELECT
        DATE_TRUNC('hour', block_time)                              AS hour_bucket,
        SUM(amount)                                                 AS eth_borrowed,
        SUM(amount_usd)                                             AS eth_borrowed_usd,
        COUNT(*)                                                    AS borrow_tx_count
    FROM lending.borrow
    WHERE blockchain   = 'ethereum'
      AND project      = 'aave'
      AND symbol       IN ('ETH', 'WETH')
      AND block_month >= TIMESTAMP '2026-04-01'
      AND block_time  >= TIMESTAMP '2026-04-16'
      AND block_time  <  TIMESTAMP '2026-04-22'
    GROUP BY 1
),

-- Step 3: Spine of hourly buckets to ensure alignment
hours_spine AS (
    SELECT hour_bucket FROM aave_rseth_supply
    UNION
    SELECT hour_bucket FROM aave_eth_borrow
),

-- Step 4: Join supply and borrow on the time spine
combined AS (
    SELECT
        s.hour_bucket,
        COALESCE(rs.rseth_supplied, 0)          AS rseth_supplied,
        COALESCE(rs.rseth_supplied_usd, 0)      AS rseth_supplied_usd,
        COALESCE(eb.eth_borrowed, 0)            AS eth_weth_borrowed,
        COALESCE(eb.eth_borrowed_usd, 0)        AS eth_weth_borrowed_usd
    FROM hours_spine s
    LEFT JOIN aave_rseth_supply  rs ON rs.hour_bucket = s.hour_bucket
    LEFT JOIN aave_eth_borrow    eb ON eb.hour_bucket = s.hour_bucket
),

-- Step 5: Cumulative borrow total (shows the ramp-up)
final AS (
    SELECT
        hour_bucket                                                 AS "Hour (UTC)",
        ROUND(rseth_supplied, 2)                                    AS "rsETH Supplied to Aave",
        ROUND(rseth_supplied_usd / 1e6, 3)                         AS "rsETH Supply USD (M)",
        ROUND(eth_weth_borrowed, 2)                                 AS "ETH/WETH Borrowed",
        ROUND(eth_weth_borrowed_usd / 1e6, 3)                      AS "ETH Borrow USD (M)",
        ROUND(
            SUM(eth_weth_borrowed) OVER (ORDER BY hour_bucket ASC),
            2
        )                                                           AS "Cumul. ETH Borrowed"
    FROM combined
)

SELECT * FROM final
ORDER BY "Hour (UTC)" ASC
