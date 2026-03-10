WITH material_dim AS (
    SELECT DISTINCT
        m.gmid_code,
        m.is_active
    FROM SHR_IA_MATERIAL_PROD.IA_MATERIAL_PROD_PBL_IA_MATERIAL.MATERIAL m
)

SELECT DISTINCT
    v.SOURCE_SYSTEM,
    v.GMID,
    'to_gmid_code' AS ATTRIBUTE,
    CASE 
        WHEN v.GMID IS NULL THEN 1 
        ELSE 0 
    END AS COMPLETENESS,
    CASE 
        WHEN v.GMID IS NULL THEN 1
        WHEN v.GMID <> v.FROM_GMID THEN 1
        ELSE 0 
    END AS ACCURACY
FROM 
    SHR_MS_PLANT_TO_MARKET_PROD.MS_PLANT_TO_MARKET_PROD_PBL_DQM.V_BILL_OF_DISTRIBUTION v
LEFT JOIN material_dim m
    ON TRY_CAST(v.GMID AS INTEGER) = TRY_CAST(m.gmid_code AS INTEGER)  -- strips leading zeros on both sides
WHERE 
    m.is_active = TRUE
AND
    v.SOURCE_SYSTEM in ('kinaxis','KINAXIS')