# 📦 Order Fulfillment Delay Analysis

**SQL • Power BI / Dashboard • Root-Cause Analysis**

A business analytics case study identifying why order-to-dispatch time was increasing, tracing the delay to a specific fulfillment stage and a specific operational cutoff rule — then quantifying the impact with SQL and visualizing it in an interactive dashboard.

---

## 🧩 Business Problem

Order-to-dispatch time had crept up to **3.1 days** against a **1.5-day target**. Operations needed to know *where* in the fulfillment pipeline (Confirm → Allocate → Pick → Pack → Handoff) the time was being lost, and *why*, so the fix could be targeted rather than guessed at.

## 🔍 Approach

1. **Extracted** order-level timestamps across all five fulfillment stages from `orders`, `inventory_allocation`, `picking_events`, `packing_events`, and `carrier_handoff` (6-month rolling window, 400 orders, 3 warehouse sites).
2. **Broke down** average duration and % share of total time per stage to isolate the bottleneck.
3. **Tested a hypothesis** that a twice-daily inventory reconciliation batch was penalizing afternoon-confirmed orders, by bucketing orders into confirmation-time windows and comparing allocation delay.
4. **Segmented by site** to check whether the issue was systemic or localized.
5. **Built a monitoring query** (rolling weekly average) to track dispatch time after the fix shipped.

## 📊 Key Findings

| Finding | Detail |
|---|---|
| **Bottleneck stage** | Confirm → Allocate accounts for **62%** of total dispatch time |
| **Root cause** | Orders confirmed after the **2pm cutoff** wait for the next batch reconciliation run |
| **Impact of cutoff** | Allocation delay is **~460% higher** for afternoon-confirmed orders vs. morning |
| **Sample** | 400 orders across 3 warehouse sites, 6-month window |

**Recommendation:** move from twice-daily batch reconciliation to near-real-time inventory sync, or add an intermediate batch run to shrink the afternoon queue window.

## 🛠️ Tools Used

- **SQL (T-SQL)** — data extraction, stage-duration calculations, cutoff hypothesis testing, site breakdown, post-fix monitoring
- **Excel** — data staging and pivot summary feeding the dashboard
- **HTML/CSS/Chart.js** — interactive dashboard mockup (built as a stand-in for / companion to a Power BI report)

## 📁 Repository Structure

```
├── sql/
│   └── fulfillment_analysis.sql      # All analysis queries (extract, stage summary, cutoff test, site breakdown, monitoring)
├── data/
│   └── Fulfillment_Analysis.xlsx     # Source/staging data + pivot tables used to build the dashboard
├── dashboard/
│   └── Fulfillment_Dashboard_final.html   # Interactive dashboard (open directly in a browser)
├── screenshots/
│   └── dashboard_preview.png         # (add a screenshot here for quick preview in the README)
└── README.md
```

## ▶️ How to View the Dashboard

The dashboard is a self-contained HTML file — no server needed.

1. Download `dashboard/Fulfillment_Dashboard_final.html`
2. Open it in any browser

Or view it live via GitHub Pages (see setup note below).

## 🖼️ Preview

*(Add a screenshot of the dashboard here once uploaded — see instructions below)*

```md
![Dashboard preview](screenshots/dashboard_preview.png)
```

## 📌 SQL Highlights

- Stage-duration CTE with `DATEDIFF` across 5 joined event tables
- Conditional bucketing (`CASE`) to test a time-of-day hypothesis against a business rule
- Site-level and week-level rollups for ongoing monitoring

---

*This is a portfolio project built to demonstrate an end-to-end analyst workflow: SQL extraction → root-cause testing → dashboard storytelling.*
