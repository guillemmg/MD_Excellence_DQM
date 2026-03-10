SELECT DISTINCT
  bod.SOURCE_SYSTEM,
  bod.GMID,
  'dock to stock lead time'              AS ATTRIBUTE,

  -- 1) Completeness: 1 when DOCK_TO_STOCK_LEAD_TIME is NULL, 0 otherwise
  CASE 
    WHEN bod.DOCK_TO_STOCK_LEAD_TIME IS NULL THEN 1
    ELSE 0
  END AS COMPLETENESS,

  -- 2) Accuracy: 0 when ALL conditions are met
  CASE 
    WHEN 
      -- a) Both values are numeric
      TRY_TO_NUMBER(bod.DOCK_TO_STOCK_LEAD_TIME::VARCHAR) IS NOT NULL
      AND TRY_TO_NUMBER(marc.WEBAZ::VARCHAR) IS NOT NULL
      -- b) WEBAZ must not be zero if MTART is 'SF' or 'AI'
      AND NOT (mara.MTART IN ('SF', 'AI') AND marc.WEBAZ = 0)
      -- c) Both values must be the same
      AND bod.DOCK_TO_STOCK_LEAD_TIME = marc.WEBAZ
    THEN 0
    ELSE 1
  END AS ACCURACY

FROM SHR_MS_PLANT_TO_MARKET_PROD.MS_PLANT_TO_MARKET_PROD_PBL_DQM.V_BILL_OF_DISTRIBUTION bod

-- Join MARC (with SOURCE_SYSTEM)
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARC marc
  ON bod.GMID = LTRIM(marc.MATNR, '0')
  AND SPLIT_PART(bod.SITE, '_', 1) = marc.WERKS
  AND marc.LVORM IS NULL

-- Join MARA to get MTART (with SOURCE_SYSTEM)
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARA mara
  ON marc.MATNR = mara.MATNR
  AND marc.SOURCE_SYSTEM = mara.SOURCE_SYSTEM

-- Filter: Only Transfer types
WHERE bod.TYPE LIKE '%Transfer%'
AND bod.SOURCE_SYSTEM IN ('kinaxis','KINAXIS')