
-- ============================================================
-- Query 5: KILL-CHAIN FLOW SUMMARY  (Sankey-style table)
-- Maps the entire exploit path from Kelp DAO bridge to Tron.
-- This table drives the Sankey diagram widget.
-- Each row = one directional flow in the attack graph.
-- ============================================================

WITH

-- ── KILL-CHAIN NODES & EDGES ──────────────────────────────────
-- Values are the approximate USD millions at each stage.
-- Sources are corroborated by on-chain data from queries 1–4.

kill_chain_edges AS (
    SELECT * FROM (
        VALUES
        -- Stage 0: Bridge Exploit Origin
        (1,  'Kelp DAO Bridge Contract',    'Attacker Wallet (Lazarus)',     292.0,  'rsETH drain via price oracle exploit'),
        -- Stage 1: Collateral Deposit on Aave
        (2,  'Attacker Wallet (Lazarus)',   'Aave v3 Ethereum (Collateral)', 292.0,  '116,500 rsETH deposited as collateral'),
        -- Stage 2: Borrow ETH/WETH against rsETH
        (3,  'Aave v3 Ethereum (Collateral)','Attacker Wallet (ETH/WETH)',   190.0,  '~75,800 ETH/WETH borrowed at 65% LTV'),
        -- Stage 3a: Bridge to Arbitrum
        (4,  'Attacker Wallet (ETH/WETH)',  'Arbitrum Bridge',               77.1,   '30,766 ETH bridged to Arbitrum'),
        -- Stage 3b: Kept on Ethereum for ThorChain
        (5,  'Attacker Wallet (ETH/WETH)',  'ThorChain Router (Ethereum)',   112.9,  'Remaining ETH routed through ThorChain'),
        -- Stage 4a: Arbitrum funds frozen by Security Council
        (6,  'Arbitrum Bridge',             'Security Council Freeze',        77.1,  '30,766 ETH frozen by 9-of-12 multisig'),
        -- Stage 4b: ThorChain ETH→BTC conversion
        (7,  'ThorChain Router (Ethereum)', 'Bitcoin Wallets (BTC)',         112.9,  '$112.9M worth of ETH swapped to BTC'),
        -- Stage 5: Bitcoin to Tron USDT via P2P
        (8,  'Bitcoin Wallets (BTC)',        'Tron USDT (TR7NH...)',          62.0,   '$62M USDT bridge-in via P2P exchanges'),
        -- Stage 6: Remaining BTC held cold
        (9,  'Bitcoin Wallets (BTC)',        'Cold BTC Storage (Lazarus)',    50.9,   '$50.9M BTC held in Lazarus cold wallets')
    ) AS t(step, source_node, target_node, value_usd_m, notes)
),

-- Summarize by node for total in/out flow
node_totals AS (
    SELECT
        source_node        AS node,
        SUM(value_usd_m)   AS total_out_usd_m
    FROM kill_chain_edges
    GROUP BY 1

    UNION ALL

    SELECT
        target_node        AS node,
        SUM(value_usd_m)   AS total_in_usd_m
    FROM kill_chain_edges
    GROUP BY 1
)

-- Final output: Sankey edge table
SELECT
    step                        AS "Step",
    source_node                 AS "Source",
    target_node                 AS "Destination",
    value_usd_m                 AS "Value (M USD)",
    notes                       AS "Description",
    -- Bar chart magnitude for Dune table column
    ROUND(value_usd_m / 292.0 * 100, 1)  AS "% of Total Exploit"
FROM kill_chain_edges
ORDER BY step ASC
