
-- ============================================================
-- #1  THE INCEPTION — Kelp DAO Bridge Drain, April 18 2026
-- Attacker  : 0x8B1b6c9A6DB1304000412dd21Ae6A70a82d60D3b
-- rsETH OFT : 0x85d456B2DfF1fd8245387C0BfB64Dfb700e98Ef3
-- rsETH ERC20: 0xa1290d69c65a6fe4df752f95823fae25cb99e5a7
-- ============================================================

WITH
  -- All ERC-20 Transfer events for rsETH on April 18-19
  rseth_transfers AS (
    SELECT
      block_time,
      tx_hash,
      "from",
      "to",
      value / 1e18                              AS amount_rseth,
      (value / 1e18) * 2506.5                   AS amount_usd,   -- ~$2,506.5/rsETH at time of exploit
      CASE
        WHEN "from" = 0x85d456B2DfF1fd8245387C0BfB64Dfb700e98Ef3
         AND "to"   = 0x8B1b6c9A6DB1304000412dd21Ae6A70a82d60D3b
        THEN 'Bridge → Attacker (EXPLOIT)'
        WHEN "from" = 0x8B1b6c9A6DB1304000412dd21Ae6A70a82d60D3b
        THEN 'Attacker → Downstream'
        ELSE 'Other'
      END                                       AS transfer_type
    FROM erc20_ethereum.evt_Transfer
    WHERE contract_address = 0xa1290d69c65a6fe4df752f95823fae25cb99e5a7
      AND block_time >= TIMESTAMP '2026-04-18 17:00:00'
      AND block_time <  TIMESTAMP '2026-04-19 06:00:00'
      AND (
            "from" = 0x85d456B2DfF1fd8245387C0BfB64Dfb700e98Ef3
         OR "to"   = 0x85d456B2DfF1fd8245387C0BfB64Dfb700e98Ef3
         OR "from" = 0x8B1b6c9A6DB1304000412dd21Ae6A70a82d60D3b
         OR "to"   = 0x8B1b6c9A6DB1304000412dd21Ae6A70a82d60D3b
          )
  ),

  -- Running total drained from bridge
  cumulative AS (
    SELECT
      block_time,
      tx_hash,
      "from",
      "to",
      amount_rseth,
      amount_usd,
      transfer_type,
      SUM(CASE WHEN transfer_type = 'Bridge → Attacker (EXPLOIT)'
               THEN amount_rseth ELSE 0 END)
        OVER (ORDER BY block_time, tx_hash)     AS cumulative_drained_rseth
    FROM rseth_transfers
  )

SELECT
  block_time                                    AS block_time,
  SUBSTRING(CAST(tx_hash AS VARCHAR), 1, 18) || '...'
                                                AS tx_hash_short,
  CAST(tx_hash AS VARCHAR)                      AS tx_hash_full,
  SUBSTRING(CAST("from" AS VARCHAR), 1, 10) || '...'
                                                AS from_addr,
  SUBSTRING(CAST("to" AS VARCHAR), 1, 10) || '...'
                                                AS to_addr,
  ROUND(amount_rseth, 2)                        AS amount_rseth,
  ROUND(amount_usd, 0)                          AS amount_usd,
  transfer_type,
  ROUND(cumulative_drained_rseth, 2)            AS cumulative_drained_rseth
FROM cumulative
ORDER BY block_time ASC
