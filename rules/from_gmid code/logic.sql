WITH
-- ------------------------------------------------------------
-- Parameters / Active filters
-- ------------------------------------------------------------
params AS (
    SELECT CURRENT_DATE AS as_of_date
),

active_bod AS (
    SELECT 
        b.*
    FROM SHR_MS_PLANT_TO_MARKET_PROD.MS_PLANT_TO_MARKET_PROD_PBL_DQM.V_BILL_OF_DISTRIBUTION b
    CROSS JOIN params p
    WHERE (b.effective_in_date IS NULL OR b.effective_in_date <= p.as_of_date)
      AND (b.effective_out_date IS NULL OR b.effective_out_date >= p.as_of_date)
),

-- GMID master data from IA.MATERIAL
material_dim AS (
    SELECT
        m.gmid_code,
        m.is_active
    FROM SHR_IA_MATERIAL_PROD.IA_MATERIAL_PROD_PBL_IA_MATERIAL.MATERIAL m
)

SELECT DISTINCT
    b.source_system AS SOURCE_SYSTEM,
    b.gmid          AS GMID,
    'from_gmid code'     AS ATTRIBUTE,

    -- COMPLETENESS: 1 = missing, 0 = OK
    CASE
        WHEN b.from_gmid IS NULL 
          OR TRIM(CAST(b.from_gmid AS VARCHAR(100))) = '' 
        THEN 1
        ELSE 0
    END AS COMPLETENESS,

    -- ACCURACY:
    -- 0 = OK only if FROM_GMID exists in IA.MATERIAL AND is active
    -- 1 = inaccurate otherwise
    CASE
        WHEN b.from_gmid IS NOT NULL AND m.is_active = 'TRUE'
            THEN 0
        ELSE 1
    END AS ACCURACY

FROM active_bod b
LEFT JOIN material_dim m
       ON LTRIM(TO_VARCHAR(m.gmid_code), '0') = b.from_gmid