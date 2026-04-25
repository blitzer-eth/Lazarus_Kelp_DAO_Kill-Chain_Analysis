
-- ============================================================
-- Query 4: THE LAUNDERING PATH
-- Part A: ThorChain ETH→BTC swaps  (~$175M stolen funds)
-- Part B: Tron USDT bridge-ins     (money laundering leg)
-- Time window: 2026-04-18 to 2026-04-30
-- ============================================================

WITH

-- ── PART A: ThorChain ETH→BTC swaps ─────────────────────────

-- Large ETH-to-BTC swaps (>$500k USD) through ThorChain
thorchain_eth_btc AS (
    SELECT
        DATE_TRUNC('day', block_timestamp)                          AS day_bucket,
        tx_id,
        from_address,
        from_asset,
        to_asset,
        ROUND(from_amount_usd, 2)                                   AS swap_usd,
        ROUND(from_amount, 4)                                       AS from_amount,
        ROUND(to_amount, 4)                                         AS to_amount,
        'ThorChain ETH→BTC'                                         AS route_label
    FROM thorchain.defi_swaps
    WHERE block_timestamp >= TIMESTAMP '2026-04-18'
      AND block_timestamp <  TIMESTAMP '2026-05-01'
      AND from_asset LIKE '%ETH%'
      AND to_asset   LIKE '%BTC%'
      AND from_amount_usd > 500000  -- Only large-value swaps
),

-- Daily aggregation of ThorChain swaps
daily_thorchain AS (
    SELECT
        day_bucket,
        COUNT(*)                                                    AS swap_count,
        ROUND(SUM(swap_usd) / 1e6, 3)                              AS total_swap_usd_m,
        ROUND(SUM(from_amount), 4)                                  AS total_eth_swapped,
        ROUND(SUM(to_amount), 4)                                    AS total_btc_received
    FROM thorchain_eth_btc
    GROUP BY 1
),

-- ── PART B: Tron USDT large bridge-ins ───────────────────────

-- USDT Transfer events on Tron (ERC-20 style via logs)
-- USDT on Tron: TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t
-- Transfer topic0: 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
tron_usdt_transfers AS (
    SELECT
        DATE_TRUNC('day', block_time)                               AS day_bucket,
        tx_hash,
        tx_from,
        tx_to,
        -- Decode USDT amount from data field (6 decimals on Tron)
        CAST(BYTEARRAY_TO_BIGINT(data) AS DOUBLE) / 1e6            AS usdt_amount
    FROM tron.logs
    WHERE block_date >= DATE '2026-04-18'
      AND block_date <  DATE '2026-05-01'
      -- USDT contract on Tron
      AND contract_address = 0x41a614f803b6fd780986a42c78ec9c7f77e6ded13  -- TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t (hex)
      -- ERC-20 Transfer event
      AND topic0 = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
),

-- Filter only large USDT movements (>$1M, likely laundering hops)
large_tron_usdt AS (
    SELECT
        day_bucket,
        COUNT(*)                                                    AS transfer_count,
        ROUND(SUM(usdt_amount) / 1e6, 3)                           AS total_usdt_m
    FROM tron_usdt_transfers
    WHERE usdt_amount > 1000000
    GROUP BY 1
),

-- ── FINAL: Combine both laundering legs ──────────────────────

all_days AS (
    SELECT day_bucket FROM daily_thorchain
    UNION
    SELECT day_bucket FROM large_tron_usdt
)

SELECT
    d.day_bucket                                                    AS "Date",
    COALESCE(tc.swap_count, 0)                                      AS "ThorChain Swap Count",
    COALESCE(tc.total_eth_swapped, 0)                               AS "ETH → BTC (ThorChain)",
    COALESCE(tc.total_btc_received, 0)                              AS "BTC Received",
    COALESCE(tc.total_swap_usd_m, 0)                                AS "ThorChain Volume (M USD)",
    COALESCE(tu.transfer_count, 0)                                  AS "Tron USDT Transfers",
    COALESCE(tu.total_usdt_m, 0)                                    AS "Tron USDT Volume (M)",
    ROUND(
        COALESCE(tc.total_swap_usd_m, 0) + COALESCE(tu.total_usdt_m, 0),
        3
    )                                                               AS "Total Laundered (M USD)"
FROM all_days d
LEFT JOIN daily_thorchain   tc ON tc.day_bucket = d.day_bucket
LEFT JOIN large_tron_usdt   tu ON tu.day_bucket = d.day_bucket
ORDER BY d.day_bucket ASC
