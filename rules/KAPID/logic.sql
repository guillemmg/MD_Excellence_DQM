SELECT DISTINCT
    /* Context */
    H.SOURCE_SYSTEM                        AS SOURCE_SYSTEM,
    T.MARA_MATNR                           AS GMID,
    'KAPID'                                AS ATTRIBUTE,

    /* ----------------------------- */
    /* 1) COMPLETENESS: KAKO_KAPID   */
    /* ----------------------------- */
    CASE
        WHEN H.KAPID IS NULL OR TRIM(H.KAPID) = '' 
            THEN 1
            ELSE 0
    END AS COMPLETENESS,

    /* ------------------------------------------------------------- */
    /* 2) ACCURACY (KO = 1)                                          */
    /*    KO only when:                                              */
    /*      - KAKO_KAPID missing, or                                 */
    /*      - referenced capacity not found in CRCA                  */
    /* ------------------------------------------------------------- */
    CASE
        WHEN H.KAPID IS NULL OR TRIM(H.KAPID) = '' 
            THEN 1            -- missing capacity
        WHEN B.KAPID IS NULL 
            THEN 1            -- CRCA missing
        ELSE 0
    END AS ACCURACY

FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_KAKO H
/* Only CRCA lookup for KAKO_KAPID */
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_CRCA B
       ON H.KAPID = B.KAPID AND H.SOURCE_SYSTEM = B.SOURCE_SYSTEM
LEFT JOIN SCLEAN_PROD.MD_BOOSTER_NEW.PP_TABS T
       ON H.KAPID = T.KAKO_KAPID AND H.SOURCE_SYSTEM = T.MARA_SOURCE_SYSTEM