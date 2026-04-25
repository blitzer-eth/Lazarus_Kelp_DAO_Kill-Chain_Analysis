
-- ============================================================
-- Query 4 v2: THE LAUNDERING PATH
-- Part A: ThorChain large ETH→BTC swaps (>$500k)
-- Part B: Tron large-value transactions (>$1M, USDT proxy)
-- Window: 2026-04-18 to 2026-04-30
-- ============================================================

WITH

-- ── PART A: ThorChain ETH→BTC swaps ─────────────────────────

thorchain_eth_btc_daily AS (
    SELECT
        CAST(DATE_TRUNC('day', block_timestamp) AS DATE)    AS day_bucket,
        COUNT(*)                                             AS swap_count,
        ROUND(SUM(from_amount_usd) / 1e6, 3)               AS total_swap_usd_m,
        ROUND(SUM(from_amount), 4)                          AS total_eth_swapped,
        ROUND(SUM(to_amount), 4)                            AS total_btc_received
    FROM thorchain.defi_swaps
    WHERE block_timestamp >= TIMESTAMP '2026-04-18'
      AND block_timestamp <  TIMESTAMP '2026-05-01'
      AND from_asset LIKE '%ETH%'
      AND to_asset   LIKE '%BTC%'
      AND from_amount_usd > 500000
    GROUP BY 1
),

-- ── PART B: Tron large-value TRX transfers as laundering proxy ──────

tron_large_tx_daily AS (
    SELECT
        block_date                                           AS day_bucket,
        COUNT(*)                                             AS tron_tx_count,
        -- TRX value is in sun (1 TRX = 1,000,000 sun), approximate USD at ~$0.12/TRX
        ROUND(
            SUM(CAST(value AS DOUBLE) / 1e6 * 0.12) / 1e6,
            3
        )                                                    AS tron_value_approx_usd_m
    FROM tron.transactions
    WHERE block_date >= DATE '2026-04-18'
      AND block_date <  DATE '2026-05-01'
      AND success = true
      AND CAST(value AS DOUBLE) / 1e6 > 1000000  -- > 1M TRX (~$120k)
    GROUP BY 1
),

-- ── SPINE: union of all days ──────────────────────────────────

all_days AS (
    SELECT day_bucket FROM thorchain_eth_btc_daily
    UNION
    SELECT day_bucket FROM tron_large_tx_daily
)

SELECT
    d.day_bucket                                            AS "Date",
    COALESCE(tc.swap_count, 0)                              AS "ThorChain ETH→BTC Swaps",
    COALESCE(tc.total_eth_swapped, 0)                       AS "ETH Swapped",
    COALESCE(tc.total_btc_received, 0)                      AS "BTC Received",
    COALESCE(tc.total_swap_usd_m, 0)                        AS "ThorChain Volume (M USD)",
    COALESCE(tu.tron_tx_count, 0)                           AS "Tron Large Tx Count",
    COALESCE(tu.tron_value_approx_usd_m, 0)                AS "Tron Value (M USD, est.)",
    ROUND(
        COALESCE(tc.total_swap_usd_m, 0)
        + COALESCE(tu.tron_value_approx_usd_m, 0),
        3
    )                                                       AS "Total Laundering Flow (M USD)"
FROM all_days d
LEFT JOIN thorchain_eth_btc_daily tc ON tc.day_bucket = d.day_bucket
LEFT JOIN tron_large_tx_daily     tu ON tu.day_bucket = d.day_bucket
ORDER BY d.day_bucket ASC
