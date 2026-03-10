SELECT DISTINCT
    bod.SOURCE_SYSTEM,
    bod.GMID,
    'effective end date' AS ATTRIBUTE,

    -- Completeness: flags when EFFECTIVE_OUT_DATE is missing
    CASE 
        WHEN bod.EFFECTIVE_OUT_DATE IS NULL OR TRIM(bod.EFFECTIVE_OUT_DATE) = '' THEN 1
        ELSE 0
    END AS Completeness,

    -- Accuracy: 
    -- Rule 1: If TYPE IN ('Make','TransferCMO_PUSH','Transfer',
    --         'Transfer_PUSH','Buy','TransferCMO','Transfer P2P','Transfer P2P_PUSH'),
    --         EFFECTIVE_OUT_DATE must not be NULL (past or future)
    -- Rule 2: If ORDER_POLICY <> 'NoOrders', EFFECTIVE_OUT_DATE must not be NULL
    CASE 
        WHEN bod.TYPE IN ('Make','TransferCMO_PUSH','Transfer',
                          'Transfer_PUSH','Buy','TransferCMO',  
                          'Transfer P2P','Transfer P2P_PUSH')
             AND (bod.EFFECTIVE_OUT_DATE IS NULL OR TRIM(bod.EFFECTIVE_OUT_DATE) = '') 
             THEN 1
        WHEN bod.ORDER_POLICY <> 'NoOrders'
             AND (bod.EFFECTIVE_OUT_DATE IS NULL OR TRIM(bod.EFFECTIVE_OUT_DATE) = '') 
             THEN 1
        ELSE 0
    END AS Accuracy

FROM SHR_MS_PLANT_TO_MARKET_PROD.MS_PLANT_TO_MARKET_PROD_PBL_DQM.V_BILL_OF_DISTRIBUTION bod

INNER JOIN SHR_MS_DEMAND_PLANNING_PROD.MS_DEMAND_PLANNING_PROD_SRV_DQM.V_PART prt
    ON bod.GMID = prt.GMID

WHERE prt.RELEVANCYKNX = '1'
AND bod.SOURCE_SYSTEM in ('kinaxis', 'KINAXIS')