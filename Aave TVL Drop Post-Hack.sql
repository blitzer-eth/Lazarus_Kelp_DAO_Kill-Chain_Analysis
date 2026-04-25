
-- ============================================================
-- Query 2b: AAVE TVL DROP
-- Daily net TVL change in Aave v3 Ethereum
-- Time window: 2026-04-10 to 2026-04-22 (before/after hack)
-- ============================================================

WITH

-- Daily net supply flow (deposits - withdrawals) in USD
daily_supply AS (
    SELECT
        DATE_TRUNC('day', block_time)               AS day_bucket,
        SUM(
            CASE
                WHEN transaction_type = 'deposit'   THEN  amount_usd
                WHEN transaction_type = 'withdraw'  THEN -amount_usd
                ELSE 0
            END
        )                                           AS net_supply_usd
    FROM lending.supply
    WHERE blockchain   = 'ethereum'
      AND project      = 'aave'
      AND block_month >= TIMESTAMP '2026-04-01'
      AND block_time  >= TIMESTAMP '2026-04-10'
      AND block_time  <  TIMESTAMP '2026-04-23'
    GROUP BY 1
),

-- Daily net borrow flow (borrows - repays) in USD
daily_borrow AS (
    SELECT
        DATE_TRUNC('day', block_time)               AS day_bucket,
        SUM(
            CASE
                WHEN transaction_type = 'borrow'    THEN  amount_usd
                WHEN transaction_type = 'repay'     THEN -amount_usd
                ELSE 0
            END
        )                                           AS net_borrow_usd
    FROM lending.borrow
    WHERE blockchain   = 'ethereum'
      AND project      = 'aave'
      AND block_month >= TIMESTAMP '2026-04-01'
      AND block_time  >= TIMESTAMP '2026-04-10'
      AND block_time  <  TIMESTAMP '2026-04-23'
    GROUP BY 1
),

-- Spine
days_spine AS (
    SELECT day_bucket FROM daily_supply
    UNION
    SELECT day_bucket FROM daily_borrow
),

-- Combined daily: TVL = cumulative net supply
combined AS (
    SELECT
        d.day_bucket,
        COALESCE(s.net_supply_usd, 0)  AS net_supply_usd,
        COALESCE(b.net_borrow_usd, 0)  AS net_borrow_usd
    FROM days_spine d
    LEFT JOIN daily_supply s ON s.day_bucket = d.day_bucket
    LEFT JOIN daily_borrow b ON b.day_bucket = d.day_bucket
)

SELECT
    day_bucket                                                  AS "Date",
    ROUND(net_supply_usd / 1e9, 3)                             AS "Net Supply Change (B USD)",
    ROUND(net_borrow_usd / 1e9, 3)                             AS "Net Borrow Change (B USD)",
    ROUND(
        SUM(net_supply_usd) OVER (ORDER BY day_bucket ASC) / 1e9,
        3
    )                                                           AS "Cumulative Aave Supply TVL (B USD)",
    CASE
        WHEN day_bucket = DATE '2026-04-18'
            THEN '🔴 HACK DAY'
        WHEN day_bucket > DATE '2026-04-18'
            THEN '⬇️ Post-Hack'
        ELSE '✅ Pre-Hack'
    END                                                         AS "Period Flag"
FROM combined
ORDER BY day_bucket ASC
