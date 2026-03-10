SELECT DISTINCT
    e.SOURCE_SYSTEM,
    pir.MATNR AS GMID,                 -- <- GMID now sourced from EINA via INFNR
    'BSTAE' AS ATTRIBUTE,

    /* ---------------- COMPLETENESS (0 = OK, 1 = KO) ---------------- */
    CASE
        /* Rule: BSTAE must not be NULL */
        WHEN e.BSTAE IS NULL THEN 1
        ELSE 0
    END AS COMPLETENESS,

    /* ------------------ ACCURACY (0 = OK, 1 = KO) ------------------ */
    CASE
        /* Only evaluate accuracy when EINE.BSTAE exists.
           Flag KO when Vendor Master also has BSTAE and the values differ. */      
         WHEN e.BSTAE IS NULL THEN 1     -- Force Accuracy to KO to be consistent with Comp
         WHEN vm.BSTAE IS NOT NULL AND e.BSTAE <> vm.BSTAE THEN 1
         ELSE 0
    END AS ACCURACY

FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINE e

/* Vendor Master (purchasing org) – inheritance check */
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_LFM2 vm
       ON vm.EKORG = e.EKORG

/* Purchasing Info Record general data (EINA) – used for GMID and inheritance logic */
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA pir
       ON pir.INFNR = e.INFNR
WHERE e.SOURCE_SYSTEM IN ('ATHENA', 'P08', 'SHIFT')
   OR e.SOURCE_SYSTEM LIKE 'ATHENA%'  -- This covers any ATHENA instance variations