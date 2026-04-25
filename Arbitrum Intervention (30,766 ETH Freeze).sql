
-- ============================================================
-- Query 3: THE ARBITRUM INTERVENTION
-- Tracks 30,766 ETH frozen by the Arbitrum Security Council
-- after the hack bridged funds to Arbitrum.
-- 
-- Known addresses:
--   Arbitrum Security Council (9-of-12 multisig):
--     0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641
--   Arbitrum Emergency Upgrade Executor:
--     0x4a4962275DF8C60a80d3a25faEc5AA7De116A746
-- ============================================================

WITH

-- Step 1: All ETH-value transactions TO or FROM the Security Council
--         on Arbitrum in the post-hack window
security_council_activity AS (
    SELECT
        block_time,
        block_number,
        hash                                                        AS tx_hash,
        "from"                                                      AS sender,
        "to"                                                        AS receiver,
        CAST(value AS DOUBLE) / 1e18                                AS eth_amount,
        -- Flag direction relative to the Security Council
        CASE
            WHEN "to" = 0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641
                THEN 'Incoming → Council'
            WHEN "from" = 0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641
                THEN 'Outgoing ← Council'
            ELSE 'Related'
        END                                                         AS flow_direction
    FROM arbitrum.transactions
    WHERE block_date >= DATE '2026-04-18'
      AND block_date <= DATE '2026-04-22'
      AND success = true
      AND CAST(value AS DOUBLE) / 1e18 > 10   -- Filter dust
      AND (
            "from" = 0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641
         OR "to"   = 0x423552c0F05baCCac5Bfa91C6dCF1dc53a0A1641
         OR "from" = 0x4a4962275DF8C60a80d3a25faEc5AA7De116A746
         OR "to"   = 0x4a4962275DF8C60a80d3a25faEc5AA7De116A746
      )
),

-- Step 2: Large ETH movements on Arbitrum in the hack window (attacker hops)
--         to capture the 30,766 ETH in transit before freezing
large_eth_movements AS (
    SELECT
        block_time,
        block_number,
        hash                                                        AS tx_hash,
        "from"                                                      AS sender,
        "to"                                                        AS receiver,
        CAST(value AS DOUBLE) / 1e18                                AS eth_amount,
        'Attacker Route'                                            AS flow_direction
    FROM arbitrum.transactions
    WHERE block_date >= DATE '2026-04-18'
      AND block_date <= DATE '2026-04-20'
      AND success = true
      AND CAST(value AS DOUBLE) / 1e18 > 1000  -- Only large hops (>1000 ETH)
),

-- Step 3: Union all relevant movements
all_movements AS (
    SELECT * FROM security_council_activity
    UNION ALL
    SELECT * FROM large_eth_movements
    WHERE tx_hash NOT IN (SELECT tx_hash FROM security_council_activity)
),

-- Step 4: Hourly aggregation for chart
hourly_summary AS (
    SELECT
        DATE_TRUNC('hour', block_time)                              AS hour_bucket,
        flow_direction,
        COUNT(*)                                                    AS tx_count,
        ROUND(SUM(eth_amount), 4)                                   AS eth_volume,
        ROUND(SUM(eth_amount) * 2506.0 / 1e6, 3)                   AS usd_volume_m
    FROM all_movements
    GROUP BY 1, 2
)

SELECT
    hour_bucket                 AS "Hour (UTC)",
    flow_direction              AS "Flow Type",
    tx_count                    AS "Tx Count",
    eth_volume                  AS "ETH Volume",
    usd_volume_m                AS "USD Volume (M)",
    ROUND(
        SUM(eth_volume) OVER (
            PARTITION BY flow_direction
            ORDER BY hour_bucket ASC
        ),
        4
    )                           AS "Cumulative ETH"
FROM hourly_summary
ORDER BY hour_bucket ASC, flow_direction ASC
