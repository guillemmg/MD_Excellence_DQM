SELECT DISTINCT
    e.SOURCE_SYSTEM,
    e.MATNR AS GMID,
    'MEINS_EINA' AS ATTRIBUTE,

    /* ---------------- COMPLETENESS (0 = OK, 1 = KO) ---------------- */
    CASE
        WHEN e.MEINS IS NULL THEN 1                 -- Cannot be NULL  [1](https://www.se80.co.uk/sap-s4-hana-fields/?tabname=msit_pir_eina_s&fieldname=lmein)
        ELSE 0
    END AS COMPLETENESS,

    /* ------------------ ACCURACY (0 = OK, 1 = KO) ------------------ */
    CASE
        /* MEINS must exist for the material in MARM (valid order unit for MATNR) */
        WHEN m_marm.MEINH IS NULL THEN 1            -- Validation against MARM  [2](https://datapanda.eu/en/sap/table/LMEIN)

        /* UMREZ / UMREN must form a valid conversion ratio */
        WHEN e.UMREZ IS NULL OR e.UMREZ <= 0 THEN 1 -- Numerator invalid  [3](https://sapstack.com/tables/tabledetails.php?table=EINA)
        WHEN e.UMREN IS NULL OR e.UMREN <= 0 THEN 1 -- Denominator invalid  [3](https://sapstack.com/tables/tabledetails.php?table=EINA)

        /* If MEINS equals material base unit → must be 1:1 */
        WHEN (e.MEINS = m_mara.MEINS AND (e.UMREZ <> 1 OR e.UMREN <> 1)) THEN 1

        ELSE 0
    END AS ACCURACY

FROM SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EINA e

/* Material master: base unit (MARA-MEINS) */
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARA m_mara
       ON m_mara.MATNR = e.MATNR
/* Material alternative units of measure (MARM) */
LEFT JOIN SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_UNIFIED.VW_SRV_UNIFIED_MARM m_marm
       ON m_marm.MATNR = e.MATNR
      AND m_marm.MEINH = e.MEINS 
