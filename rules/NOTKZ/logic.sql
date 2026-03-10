WITH

-- ============================================================
-- STEP 1: BASE EXTRACTION
-- Pull all relevant EORD records from the unified view.
--
-- SCOPE FILTERS (applied in WHERE clause):
--   - SOURCE_SYSTEM filter → Restrict to ATHENA instances, P08, SHIFT
--
-- Additional EORD fields pulled for enhanced accuracy checks:
--   - AUTET  : MRP type — used in Check 1
--   - FLIFN  : Fixed vendor flag — used in Check 2
--   - BDATU  : Valid to date — used in Check 3
-- ============================================================
BASE_EORD AS (
    SELECT DISTINCT
        EORD.SOURCE_SYSTEM,
        EORD.MATNR,
        EORD.WERKS,
        EORD.LIFNR,
        EORD.NOTKZ,
        EORD.AUTET,       -- MRP Type / Source List Usage (Check 1)
        EORD.FLIFN,       -- Fixed Vendor Flag             (Check 2)
        EORD.BDATU        -- Valid To Date                 (Check 3)
    FROM
        SHR_HUB_SAP_PROD.HUB_SAP_PROD_SRV_MNS_EXTENDED.VW_SRV_UNIFIED_EORD AS EORD

    WHERE
        -- Restrict to relevant source systems:
        -- ATHENA instances (all systems with 'ATHENA' in the name), P08, SHIFT
        (
            EORD.SOURCE_SYSTEM LIKE '%ATHENA%'
            OR EORD.SOURCE_SYSTEM IN ('P08', 'SHIFT')
        )
),

-- ============================================================
-- STEP 2: DQ EVALUATION
-- Apply Completeness and enhanced Accuracy rules on NOTKZ.
--
-- COMPLETENESS:
--   KO (1) → NOTKZ IS NULL or NOTKZ = '' (empty string)
--   OK (0) → NOTKZ has any non-null, non-empty value
--
-- ACCURACY (combined — KO if ANY sub-check fails):
--
--   CHECK C — Consistency Rule (evaluated first):
--     KO (1) → COMPLETENESS = 1
--     Rationale: If NOTKZ is missing, accuracy validation is
--     meaningless. Incomplete data is inherently inaccurate.
--     This prevents misleading scenarios where a NULL record
--     appears as "accurate" in DQ reporting.
--
--   CHECK 0 — Basic Domain Validation:
--     KO (1) → NOTKZ is not in ('X', '', ' ')
--     OK (0) → NOTKZ is within the valid domain
--
--   CHECK 1 — Blocked Source with MRP Relevance:
--     KO (1) → NOTKZ = 'X' AND AUTET IN ('1','2')
--     Business: A blocked supplier should never be MRP-relevant.
--               AUTET '1' or '2' means the record participates in
--               MRP planning runs. Blocking + MRP relevance creates
--               a procurement planning conflict that must be resolved.
--
--   CHECK 2 — Blocked Source with Fixed Vendor Flag:
--     KO (1) → NOTKZ = 'X' AND FLIFN = 'X'
--     Business: A fixed vendor (FLIFN = 'X') is the designated
--               preferred supplier for a material-plant combination.
--               It is contradictory to simultaneously block and
--               designate a supplier as fixed — this indicates a
--               data inconsistency requiring review.
--
--   CHECK 3 — Expired Blocking Without Cleanup:
--     KO (1) → NOTKZ = 'X' AND BDATU < CURRENT_DATE - 365
--     Business: BDATU is the valid-to date of the source list record.
--               A blocking flag whose validity end date is more than
--               1 year in the past without review or removal suggests
--               stale data. Such records should be periodically
--               reviewed and either confirmed or cleaned up to
--               maintain data integrity.
-- ============================================================
DQ_CHECKS AS (
    SELECT
        SOURCE_SYSTEM,
        MATNR,
        WERKS,
        LIFNR,
        NOTKZ,
        AUTET,
        FLIFN,
        BDATU,

        -- --------------------------------------------------
        -- COMPLETENESS CHECK
        -- KO = 1 : NOTKZ is NULL or blank (no value present)
        -- OK = 0 : NOTKZ has a value
        -- --------------------------------------------------
        CASE
            WHEN NOTKZ IS NULL
              OR TRIM(NOTKZ) = ''
            THEN 1   -- KO: field is empty or missing
            ELSE 0   -- OK: field has a value
        END AS COMPLETENESS,

        -- --------------------------------------------------
        -- ACCURACY CHECK (Enhanced — 5 sub-checks combined)
        -- KO = 1 : ANY of the sub-checks below is triggered
        -- OK = 0 : ALL sub-checks pass
        --
        -- CONSISTENCY RULE (Check C):
        -- If COMPLETENESS = 1 (NOTKZ is NULL or empty), then
        -- ACCURACY is also set to 1 (KO). This ensures logical
        -- consistency in DQ reporting: a record that is incomplete
        -- cannot be reported as accurate. Evaluating accuracy on
        -- a missing value would produce a meaningless result and
        -- could mislead downstream DQ dashboards and metrics.
        -- --------------------------------------------------
        CASE
            -- CHECK C: Consistency rule — incomplete = inaccurate
            -- If NOTKZ is NULL or empty, accuracy validation is
            -- not meaningful. Flag as KO for logical consistency.
            WHEN NOTKZ IS NULL
              OR TRIM(NOTKZ) = ''
            THEN 1   -- KO: completeness failure implies accuracy failure

            -- CHECK 0: Basic domain validation
            -- NOTKZ must be 'X' (blocked) or blank/space (not blocked)
            WHEN TRIM(NOTKZ) NOT IN ('X', '')
            THEN 1   -- KO: unexpected value in domain

            -- CHECK 1: Blocked source with MRP relevance
            -- A blocked supplier (NOTKZ = 'X') should not be MRP-relevant.
            -- AUTET IN ('1','2') means the record is used in planning runs,
            -- which conflicts with the blocking status.
            WHEN NOTKZ = 'X'
             AND AUTET IN ('1', '2')
            THEN 1   -- KO: blocked supplier is MRP-relevant (planning conflict)

            -- CHECK 2: Blocked source with fixed vendor flag
            -- A blocked supplier (NOTKZ = 'X') cannot simultaneously be
            -- the fixed/preferred vendor (FLIFN = 'X') for the same
            -- material-plant combination. This is a logical contradiction.
            WHEN NOTKZ = 'X'
             AND FLIFN = 'X'
            THEN 1   -- KO: blocked supplier is also the fixed vendor

            -- CHECK 3: Expired blocking without cleanup
            -- A blocking flag (NOTKZ = 'X') with a valid-to date (BDATU)
            -- older than 365 days indicates the block has not been reviewed
            -- or cleaned up within the expected maintenance window.
            WHEN NOTKZ = 'X'
             AND BDATU < CURRENT_DATE - 365
            THEN 1   -- KO: stale blocking flag (valid-to date >1 year ago)

            ELSE 0   -- OK: all accuracy checks passed
        END AS ACCURACY

    FROM BASE_EORD
)

-- ============================================================
-- STEP 3: FINAL OUTPUT
-- Project the required output columns as per DQM specification.
-- ATTRIBUTE column is hardcoded to 'NOTKZ' for traceability.
-- ============================================================
SELECT
    SOURCE_SYSTEM,
    MATNR                   AS GMID,
    'NOTKZ'                 AS ATTRIBUTE,
    COMPLETENESS,           -- 1 = KO (fail) | 0 = OK (pass)
    ACCURACY                -- 1 = KO (fail) | 0 = OK (pass)

FROM DQ_CHECKS

-- Optional: surface only records with at least one DQ issue
-- Uncomment the line below to filter KO records only:
-- WHERE COMPLETENESS = 1 OR ACCURACY = 1

ORDER BY
    SOURCE_SYSTEM,
    GMID