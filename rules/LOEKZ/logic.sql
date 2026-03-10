SELECT DISTINCT
    EINE.SOURCE_SYSTEM,
    EINE.INFNR AS GMID,
    CASE 
        WHEN EINE.SOURCE_SYSTEM IS NULL OR TRIM(EINE.SOURCE_SYSTEM) = '' THEN 'deactivation flag'
        ELSE 'deactivation flag'
    END AS ATTRIBUTE,

    /* --- COMPLETENESS RULE: PEINH present or missing --- */
    CASE 
        WHEN (IFNULL(EINE.INFNR,'') = '')  THEN 1
        ELSE 0
    END AS Completeness,

    /* --- ACCURACY RULE (UPDATED):
       Accuracy = 1 when:
       - PIR exists  (INFNR not null/blank)
       - AND ( EINE.PRDAT < Today OR PLANT not deleted)
       Otherwise Accuracy = 0
    --- */
    CASE 
        WHEN (IFNULL(EINE.INFNR,'') != '' ) 
            AND (IFNULL(MARC.LVORM ,'') = '' )  -- Plant is active
            AND EINE.LOEKZ != 'X'   -- PIR not deleted 
        THEN 1
        ELSE 0
    END AS Accuracy

FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE AS EINE
INNER JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARC AS MARC
    USING (SOURCE_SYSTEM,WERKS)
WHERE  TRUE 
    AND EINE.PRDAT < CURRENT_DATE()  -- PIR  Validity date  < Today
