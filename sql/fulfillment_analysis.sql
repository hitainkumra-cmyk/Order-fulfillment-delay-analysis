/* ===================================================================
   ORDER FULFILLMENT DELAY ANALYSIS
   Business Analyst: [Your Name]
   Purpose: Identify which fulfillment stage is driving the increase
            in order-to-dispatch time, and test the "afternoon cutoff"
            hypothesis against a twice-daily inventory reconciliation.
   Source tables: orders, inventory_allocation, picking_events,
                  packing_events, carrier_handoff
   =================================================================== */


/* -------------------------------------------------------------------
   1. BASE EXTRACT
   Pull one row per order with a timestamp at every stage, and the
   duration (in hours) between each consecutive stage.
   ------------------------------------------------------------------- */
SELECT
    o.order_id,
    o.site,
    o.order_type,
    o.confirmed_at,
    a.allocated_at,
    p.picked_at,
    pk.packed_at,
    c.handed_to_carrier_at,
    DATEPART(hour, o.confirmed_at)                                AS confirm_hour,
    DATEDIFF(minute, o.confirmed_at, a.allocated_at)   / 60.0      AS hrs_confirm_to_allocate,
    DATEDIFF(minute, a.allocated_at, p.picked_at)      / 60.0      AS hrs_allocate_to_pick,
    DATEDIFF(minute, p.picked_at, pk.packed_at)        / 60.0      AS hrs_pick_to_pack,
    DATEDIFF(minute, pk.packed_at, c.handed_to_carrier_at) / 60.0  AS hrs_pack_to_handoff,
    DATEDIFF(minute, o.confirmed_at, c.handed_to_carrier_at) / 60.0 AS hrs_total_confirm_to_handoff
FROM orders o
JOIN inventory_allocation a  ON a.order_id = o.order_id
JOIN picking_events p        ON p.order_id = o.order_id
JOIN packing_events pk       ON pk.order_id = o.order_id
JOIN carrier_handoff c       ON c.order_id = o.order_id
WHERE o.confirmed_at >= DATEADD(month, -6, GETDATE());


/* -------------------------------------------------------------------
   2. STAGE-BY-STAGE SUMMARY
   Average and median duration per stage, and each stage's share of
   total dispatch time — used to identify where the delay is
   concentrated (Finding: confirm→allocate = 62% of total time).
   ------------------------------------------------------------------- */
WITH stage_durations AS (
    SELECT
        o.order_id,
        DATEDIFF(minute, o.confirmed_at, a.allocated_at)   / 60.0 AS hrs_confirm_to_allocate,
        DATEDIFF(minute, a.allocated_at, p.picked_at)      / 60.0 AS hrs_allocate_to_pick,
        DATEDIFF(minute, p.picked_at, pk.packed_at)        / 60.0 AS hrs_pick_to_pack,
        DATEDIFF(minute, pk.packed_at, c.handed_to_carrier_at) / 60.0 AS hrs_pack_to_handoff
    FROM orders o
    JOIN inventory_allocation a  ON a.order_id = o.order_id
    JOIN picking_events p        ON p.order_id = o.order_id
    JOIN packing_events pk       ON pk.order_id = o.order_id
    JOIN carrier_handoff c       ON c.order_id = o.order_id
    WHERE o.confirmed_at >= DATEADD(month, -6, GETDATE())
)
SELECT
    'Confirm -> Allocate' AS stage, AVG(hrs_confirm_to_allocate) AS avg_hrs, COUNT(*) AS n_orders
FROM stage_durations
UNION ALL
SELECT 'Allocate -> Pick', AVG(hrs_allocate_to_pick), COUNT(*) FROM stage_durations
UNION ALL
SELECT 'Pick -> Pack', AVG(hrs_pick_to_pack), COUNT(*) FROM stage_durations
UNION ALL
SELECT 'Pack -> Handoff', AVG(hrs_pack_to_handoff), COUNT(*) FROM stage_durations
ORDER BY avg_hrs DESC;


/* -------------------------------------------------------------------
   3. ROOT CAUSE — CUTOFF EFFECT TEST
   Buckets orders by the hour they were confirmed and compares average
   allocation delay across buckets, to test whether the twice-daily
   batch reconciliation (10am / 10pm) explains the bottleneck.
   ------------------------------------------------------------------- */
SELECT
    CASE
        WHEN DATEPART(hour, o.confirmed_at) < 10 THEN '1. Before 10:00 (morning)'
        WHEN DATEPART(hour, o.confirmed_at) < 14 THEN '2. 10:00-13:59 (midday)'
        ELSE '3. 14:00 and later (afternoon cutoff)'
    END AS confirmation_window,
    AVG(DATEDIFF(minute, o.confirmed_at, a.allocated_at) / 60.0)  AS avg_hrs_to_allocate,
    COUNT(*)                                                       AS n_orders
FROM orders o
JOIN inventory_allocation a ON a.order_id = o.order_id
WHERE o.confirmed_at >= DATEADD(month, -6, GETDATE())
GROUP BY
    CASE
        WHEN DATEPART(hour, o.confirmed_at) < 10 THEN '1. Before 10:00 (morning)'
        WHEN DATEPART(hour, o.confirmed_at) < 14 THEN '2. 10:00-13:59 (midday)'
        ELSE '3. 14:00 and later (afternoon cutoff)'
    END
ORDER BY confirmation_window;


/* -------------------------------------------------------------------
   4. SITE-LEVEL BREAKDOWN
   Same stage analysis split by warehouse site, to check whether the
   bottleneck is systemic or concentrated at specific locations.
   ------------------------------------------------------------------- */
SELECT
    o.site,
    AVG(DATEDIFF(minute, o.confirmed_at, a.allocated_at) / 60.0) AS avg_hrs_confirm_to_allocate,
    AVG(DATEDIFF(minute, o.confirmed_at, c.handed_to_carrier_at) / 60.0) AS avg_hrs_total,
    COUNT(*) AS n_orders
FROM orders o
JOIN inventory_allocation a ON a.order_id = o.order_id
JOIN carrier_handoff c      ON c.order_id = o.order_id
WHERE o.confirmed_at >= DATEADD(month, -6, GETDATE())
GROUP BY o.site
ORDER BY avg_hrs_total DESC;


/* -------------------------------------------------------------------
   5. POST-IMPLEMENTATION MONITORING
   Rolling weekly average of total dispatch time, used to confirm the
   fix (near-real-time sync + revised batching rule) held after launch.
   Filter start date to the go-live date when running post-launch.
   ------------------------------------------------------------------- */
SELECT
    DATEPART(year, o.confirmed_at)  AS yr,
    DATEPART(week, o.confirmed_at)  AS wk,
    AVG(DATEDIFF(minute, o.confirmed_at, c.handed_to_carrier_at) / 60.0 / 24.0) AS avg_days_total,
    COUNT(*) AS n_orders
FROM orders o
JOIN carrier_handoff c ON c.order_id = o.order_id
WHERE o.confirmed_at >= '2026-01-01'  -- set to go-live date
GROUP BY DATEPART(year, o.confirmed_at), DATEPART(week, o.confirmed_at)
ORDER BY yr, wk;
