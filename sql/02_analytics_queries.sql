-- ============================================================
-- Pharmacy Claims Star Schema — Analytics & Reporting Queries
-- Author: Sunil Thirumani  |  Engine: MySQL 8.x
-- Run after 01_schema_and_load.sql
-- ============================================================
USE pharmacy_claims;

-- ------------------------------------------------------------
-- Q1 — Prescription volume by drug
-- Business question: Which drugs are filled most often?
-- ------------------------------------------------------------
SELECT
    dd.drug_name,
    COUNT(*) AS total_prescriptions
FROM fact_prescription fp
JOIN dim_drug dd ON fp.drug_ndc = dd.drug_ndc
GROUP BY dd.drug_name
ORDER BY total_prescriptions DESC;

-- ------------------------------------------------------------
-- Q2 — Cost & utilization by age band (CASE logic)
-- Business question: How do seniors (65+) compare to under-65
-- members on prescription volume and plan cost?
-- ------------------------------------------------------------
SELECT
    CASE WHEN dm.member_age >= 65 THEN 'age 65+' ELSE '< 65' END AS age_group,
    COUNT(*)                       AS total_prescriptions,
    COUNT(DISTINCT fp.member_id)   AS unique_members,
    SUM(fp.copay)                  AS total_copay,
    SUM(fp.insurance_paid)         AS total_insurance_paid
FROM fact_prescription fp
JOIN dim_member dm ON fp.member_id = dm.member_id
GROUP BY age_group
ORDER BY age_group;

-- ------------------------------------------------------------
-- Q3 — Most recent fill per member (window functions)
-- Business question: For each member, what was their latest
-- fill and what did the plan pay? (with prior-fill comparison)
-- ------------------------------------------------------------
WITH prescription_window AS (
    SELECT
        fp.member_id,
        dm.member_first_name,
        dm.member_last_name,
        dd.drug_name,
        fp.fill_date,
        fp.insurance_paid,
        ROW_NUMBER() OVER (PARTITION BY fp.member_id ORDER BY fp.fill_date DESC) AS rn,
        LEAD(fp.fill_date)      OVER (PARTITION BY fp.member_id ORDER BY fp.fill_date DESC) AS previous_fill_date,
        LEAD(fp.insurance_paid) OVER (PARTITION BY fp.member_id ORDER BY fp.fill_date DESC) AS previous_insurance_paid
    FROM fact_prescription fp
    JOIN dim_member dm ON fp.member_id = dm.member_id
    JOIN dim_drug   dd ON fp.drug_ndc  = dd.drug_ndc
)
SELECT
    member_id, member_first_name, member_last_name,
    drug_name, fill_date, insurance_paid,
    previous_fill_date, previous_insurance_paid
FROM prescription_window
WHERE rn = 1
ORDER BY member_id;
