# 🔴 Lazarus Kelp DAO Kill-Chain Analysis

[View Dashboard on Dune](https://dune.com/blitzer/lazarus-kelp-dao-kill-chain-analysis)

This dashboard reconstructs the complete attack chain of the **April 18, 2026 Kelp DAO bridge exploit**, attributed to the Lazarus Group (DPRK). A price oracle manipulation on the LRT bridge enabled the theft of ~116,500 rsETH (~$292M), which was subsequently laundered through Aave v3, the Arbitrum bridge, ThorChain, and the Tron network. The suite is designed for on-chain security researchers, protocol analysts, and incident responders who need a single pane of glass for the full kill-chain — from the root exploit transaction to final USDT settlement.

---

## 📸 Snapshot

<img width="3734" height="9679" alt="image" src="https://github.com/user-attachments/assets/6fbfdc3d-16db-4048-b485-90ddfc462fb0" />

---

## 🔍 Query Breakdown

### 1. The Inception — rsETH Exploit Transaction Log

Reconstructs the precise sequence of rsETH movements originating from the Kelp DAO LRT bridge on April 18, 2026.

- **Root Drain Identification:** Pinpoints the single primary drain transaction (`Hop #13`, Block 24,908,285) where 116,500 rsETH ($291.9M) was transferred from the Kelp bridge contract to the attacker's staging wallet.
- **82-Hop Trace:** Tracks every transfer event above the 100 rsETH threshold across the exploit window, classifying each hop into severity tiers (Primary Drain / Major Transfer / Intermediate Hop / Small Transfer).
- **Cumulative Drain Progress Bar:** A running total column shows how quickly the full exploit volume was dispersed across wallets in under 3 hours.

### 2. Aave Contagion — Stolen rsETH Collateral vs. ETH/WETH Borrow Spike

A dual-axis time-series chart showing the correlated supply and borrow activity on Aave v3 Ethereum across the pre/post-hack window (April 16–21, 2026).

- **Collateral Abuse Detection:** Tracks hourly rsETH deposits into Aave v3 to identify when stolen tokens were weaponized as collateral. Peak hour (17:00 UTC, Apr 18) saw 53,400 rsETH deposited in a single hour.
- **Borrow Spike Correlation:** Overlays ETH/WETH borrow volume on a right Y-axis, revealing the attacker's 65% LTV leverage play that extracted ~75,800 ETH/WETH.
- **Cumulative Borrow Tracking:** A window function accumulates total ETH borrowed over time, exposing the full scale of the Aave contagion leg.

### 2b. Aave TVL Trend — Daily Supply Change Pre/Post Hack

A companion line chart showing daily net supply changes in Aave v3 Ethereum to contextualize the protocol-level impact.

- **Pre/Post Flag:** Each data point is labeled as `✅ Pre-Hack`, `🔴 HACK DAY`, or `⬇️ Post-Hack` for at-a-glance period identification.
- **Net Flow Decomposition:** Separates deposit and withdrawal flows to show the true direction of capital movement rather than gross volume.

### 3. Arbitrum Intervention — 30,766 ETH Bridged & Frozen

Visualizes the ETH movements on Arbitrum routed by the attacker, and the subsequent emergency freeze executed by the Arbitrum Security Council.

- **Large-Value Filter:** Filters `arbitrum.transactions` to native ETH transfers above 1,000 ETH, isolating only the attacker's batched bridge transactions from background noise.
- **Security Council Scope:** Monitors addresses associated with the 9-of-12 Arbitrum Security Council multisig (`0x4235...`) and the Emergency Upgrade Executor (`0x4a49...`) for freeze-related activity.
- **Cumulative Route Tracking:** A running sum per flow type shows the total ETH captured in transit, confirming the ~$77M that was frozen and effectively recovered.

### 4. The Laundering Path — ThorChain BTC & Tron USDT Flows

Identifies the two parallel laundering legs used to off-ramp the remaining ~$113M of stolen ETH post-Arbitrum.

- **ThorChain ETH→BTC Swaps:** Queries `thorchain.defi_swaps` for large-value ETH-to-BTC conversions (>$500k USD) in the post-hack window, consistent with Lazarus Group's known cross-chain laundering TTPs.
- **Tron Large-Value Proxy:** Uses `tron.transactions` filtered to transfers above 1M TRX as a laundering velocity proxy, capturing the dramatic spike of 2,532 large transactions on April 19 alone.
- **Dual-Bar Stacked View:** Combines both laundering legs into a single stacked column chart to show total daily off-ramp pressure by channel.

### 5. Kill-Chain Flow Summary — Complete Attack Graph (Sankey Map)

A structured edge table and pie chart mapping all 9 nodes in the full attack graph, from the Kelp DAO bridge to Lazarus cold wallets and Tron USDT.

- **Sankey Edge Table:** Each row represents one directional flow in the attack graph, with USD value, description, and a progress bar showing each step as a percentage of the $292M total exploit.
- **Fund Destination Pie Chart:** Breaks down the final resting state of funds across four buckets — Arbitrum freeze (recovered), BTC cold storage (at risk), Tron USDT (laundering), and Aave residual (partially recovered).
- **Recovery Accounting:** Surfaces the $77.1M frozen by the Security Council as a concrete recovered amount, enabling incident response teams to track net exposure.

---

## 📊 Key On-Chain Findings

| Metric | Value |
|---|---|
| Total rsETH Stolen | ~116,500 rsETH (~$292M) |
| Primary Drain Block | 24,908,285 (2026-04-18 17:37 UTC) |
| Attacker Staging Wallet | `0x8b1b6c9a6db1304000412dd21ae6a70a82d60d3b` |
| Kelp Bridge Origin | `0x85d456b2dff1fd8245387c0bfb64dfb700e98ef3` |
| Aave Peak-Hour Borrow | ~51,576 ETH/WETH (17:00 UTC, Apr 18) |
| ETH Bridged to Arbitrum | ~30,766 ETH (~$77.1M) |
| Amount Frozen (Recovered) | $77.1M by Arbitrum Security Council |
| ThorChain BTC Conversion | ~$112.9M ETH→BTC |
| Tron USDT Settlement (est.) | ~$62.0M |

---

## 🛠️ Data Sources

| Component | Dune Table | Chain |
|---|---|---|
| rsETH Transfer Events | `kelpdao_ethereum.rseth_evt_transfer` | Ethereum |
| Aave Supply Flows | `lending.supply` | Ethereum |
| Aave Borrow Flows | `lending.borrow` | Ethereum |
| Arbitrum ETH Movements | `arbitrum.transactions` | Arbitrum |
| ThorChain Swaps | `thorchain.defi_swaps` | ThorChain |
| Tron Large-Value Flows | `tron.transactions` | Tron |

---

## 🧱 SQL Engineering Notes

- All queries use **Common Table Expressions (CTEs)** for readability and modularity.
- Partition pruning is applied on `block_date` / `block_month` across all partitioned tables to minimize credit consumption.
- The `lending.supply` and `lending.borrow` Spellbook spells are filtered to `project = 'aave'` and `blockchain = 'ethereum'` to avoid cross-chain noise.
- ThorChain swap detection uses `from_asset LIKE '%ETH%' AND to_asset LIKE '%BTC%' AND from_amount_usd > 500000` to surface only large institutional-scale swaps consistent with nation-state laundering.
- The Tron laundering proxy uses native TRX value (`> 1M TRX`) as a stand-in for USDT velocity given the absence of a decoded USDT Transfer table with confirmed Tron addresses at indexing time.

---

## ⚠️ Disclaimer

This dashboard is produced for **research and educational purposes only**. All wallet address attributions are based on on-chain behavioral patterns and are not legal determinations. The Lazarus Group attribution follows public reporting from Chainalysis, UN Panel of Experts, and OFAC designations. Nothing in this dashboard constitutes financial or legal advice.

---

*🔍 Powered by [Dune Analytics](https://dune.com) · Built with DuneSQL · Data across Ethereum, Arbitrum, ThorChain, and Tron*
