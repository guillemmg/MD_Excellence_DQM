WITH demand AS (
    SELECT
        SPLIT_PART(GMID, '|', 1) AS partname,
        SPLIT_PART(GMID, '|', 2) AS partsite,
        SUM(BALANCE_DELTA) AS demand_qty
    FROM SHR_MS_DEMAND_PLANNING_PROD.MS_DEMAND_PLANNING_PROD_PBL_DQM.V_PLANNING_SHEET_TOTALDEMAND
    GROUP BY 1,2
    HAVING SUM(BALANCE_DELTA) > 0
),

forecast AS (
    SELECT
        SPLIT_PART(GMID, '|', 1) AS partname,
        SPLIT_PART(GMID, '|', 2) AS partsite,
        SUM(EFFECTIVE_QUANTITY) AS fcst_qty
    FROM SHR_MS_DEMAND_PLANNING_PROD.MS_DEMAND_PLANNING_PROD_PBL_DQM.V_PLANNING_FORECAST
    WHERE "DATE" > CURRENT_DATE
    GROUP BY 1,2
    HAVING SUM(EFFECTIVE_QUANTITY) > 0
),

/* Determine ACTIVE items (must have demand > 0 or forecast > 0) */
active_items AS (
    SELECT
        COALESCE(d.partname, f.partname) AS partname,
        COALESCE(d.partsite, f.partsite) AS partsite,
        COALESCE(d.demand_qty, 0) AS total_demand_qty,
        COALESCE(f.fcst_qty, 0) AS total_fcst_qty,
        CASE
            WHEN COALESCE(d.demand_qty, 0) > 0
              OR COALESCE(f.fcst_qty, 0) > 0
            THEN 'YES'
            ELSE 'NO'
        END AS active_ind
    FROM demand d
    FULL OUTER JOIN forecast f
      ON d.partname = f.partname
     AND d.partsite = f.partsite
),

/* Site attributes */
site_dim AS (
    SELECT
        GMID AS site_gmid,
        SITE AS site,
        SOURCE_SYSTEM,
        ORDER_POLICY,
        EFFECTIVE_IN_DATE,
        EFFECTIVE_OUT_DATE
    FROM SHR_MS_PLANT_TO_MARKET_PROD.MS_PLANT_TO_MARKET_PROD_PBL_DQM.V_BILL_OF_DISTRIBUTION
)

SELECT
    sd.SOURCE_SYSTEM,
    ai.partname AS GMID,
    'order policy' AS ATTRIBUTE,

    /* Completeness: 1 = KO (missing), 0 = OK */
    CASE WHEN COALESCE(TRIM(sd.ORDER_POLICY), '') = '' THEN 1 ELSE 0 END AS COMPLETENESS,

    /* Accuracy: only active items are checked */
    CASE 
        WHEN
            COALESCE(TRIM(sd.ORDER_POLICY), '') <> 'NoOrders'
            OR sd.EFFECTIVE_OUT_DATE < CURRENT_DATE
            OR sd.EFFECTIVE_IN_DATE  > DATEADD(year, 3, CURRENT_DATE)
        THEN 0
        ELSE 1
    END AS ACCURACY

FROM active_items ai
JOIN site_dim sd
  ON sd.site_gmid = ai.partname
 AND sd.site      = ai.partsite
WHERE ai.active_ind = 'YES' 