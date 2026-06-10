-- ============================================================
-- Pharmacy Claims Star Schema — Data Quality Checks (extension)
-- Author: Sunil Thirumani  |  Engine: MySQL 8.x
-- ------------------------------------------------------------
-- These validation queries go beyond the original coursework.
-- They are the kind of checks a data engineer / analytics
-- engineer runs to confirm a load is trustworthy before it
-- feeds dashboards or models. Each query should return ZERO
-- rows if the warehouse is healthy.
-- ============================================================
USE pharmacy_claims;

-- 1) Orphan check: every fact row must map to a real member
SELECT fp.*
FROM fact_prescription fp
LEFT JOIN dim_member dm ON fp.member_id = dm.member_id
WHERE dm.member_id IS NULL;

-- 2) Orphan check: every fact row must map to a real drug
SELECT fp.*
FROM fact_prescription fp
LEFT JOIN dim_drug dd ON fp.drug_ndc = dd.drug_ndc
WHERE dd.drug_ndc IS NULL;

-- 3) Every drug must reference a valid form and brand/generic code
SELECT dd.*
FROM dim_drug dd
LEFT JOIN dim_drug_form df ON dd.drug_form_code = df.drug_form_code
LEFT JOIN dim_brand_generic bg ON dd.drug_brand_generic_code = bg.drug_brand_generic_code
WHERE df.drug_form_code IS NULL OR bg.drug_brand_generic_code IS NULL;

-- 4) No negative or impossible monetary values
SELECT *
FROM fact_prescription
WHERE copay < 0 OR insurance_paid < 0;

-- 5) Fill dates should not be in the future
SELECT *
FROM fact_prescription
WHERE fill_date > CURDATE();

-- 6) Member age should be consistent with birth date (+/- 1 yr tolerance)
SELECT member_id, member_birth_date, member_age,
       TIMESTAMPDIFF(YEAR, member_birth_date, CURDATE()) AS computed_age
FROM dim_member
WHERE ABS(TIMESTAMPDIFF(YEAR, member_birth_date, CURDATE()) - member_age) > 1;

-- 7) Duplicate natural-key check on each dimension (should be 0)
SELECT member_id, COUNT(*) c FROM dim_member GROUP BY member_id HAVING c > 1;
SELECT drug_ndc,  COUNT(*) c FROM dim_drug   GROUP BY drug_ndc  HAVING c > 1;

-- ------------------------------------------------------------
-- Reconciliation summary (eyeball totals against source)
-- ------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM fact_prescription) AS fact_rows,
    (SELECT COUNT(*) FROM dim_member)        AS members,
    (SELECT COUNT(*) FROM dim_drug)          AS drugs,
    (SELECT SUM(copay) FROM fact_prescription)          AS total_copay,
    (SELECT SUM(insurance_paid) FROM fact_prescription) AS total_insurance_paid;
