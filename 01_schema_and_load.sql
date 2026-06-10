-- ============================================================
-- Pharmacy Claims Star Schema — Schema Creation, Load & Keys
-- Author: Sunil Thirumani
-- Engine: MySQL 8.x
-- ------------------------------------------------------------
-- Originally built for ALY6030 (Data Warehousing & SQL),
-- Northeastern University. Cleaned and packaged for GitHub.
--
-- Design summary:
--   * Source data arrived as a denormalized flat file with
--     repeating fill-event groups (fill_date1..3, copay1..3,
--     insurancepaid1..3) -> violated 1NF.
--   * Normalized to 3NF: 1 fact table + 4 conformed dimensions
--     in a classic star schema.
--   * Descriptive attributes (drug_form_desc, brand/generic_desc)
--     were split into their own dimensions to remove transitive
--     dependencies (drug_ndc -> code -> desc).
-- ============================================================

CREATE DATABASE IF NOT EXISTS pharmacy_claims;
USE pharmacy_claims;

-- Drop in FK-safe order (fact first, then dimensions)
DROP TABLE IF EXISTS fact_prescription;
DROP TABLE IF EXISTS dim_drug;
DROP TABLE IF EXISTS dim_drug_form;
DROP TABLE IF EXISTS dim_brand_generic;
DROP TABLE IF EXISTS dim_member;

-- ------------------------------------------------------------
-- Dimension tables
-- ------------------------------------------------------------

-- dim_member — PK member_id (natural key, assigned by PBM source system)
CREATE TABLE dim_member (
    member_id           INT            NOT NULL,
    member_first_name   VARCHAR(100)   NOT NULL,
    member_last_name    VARCHAR(100)   NOT NULL,
    member_birth_date   DATE           NOT NULL,
    member_age          INT            NOT NULL,
    member_gender       CHAR(1)        NOT NULL,
    PRIMARY KEY (member_id)
);

-- dim_drug_form — PK drug_form_code (natural key)
-- Split from dim_drug to remove transitive dependency
-- drug_ndc -> drug_form_code -> drug_form_desc.
CREATE TABLE dim_drug_form (
    drug_form_code      CHAR(2)        NOT NULL,
    drug_form_desc      VARCHAR(100)   NOT NULL,
    PRIMARY KEY (drug_form_code)
);

-- dim_brand_generic — PK drug_brand_generic_code (natural key)
-- Split from dim_drug to remove transitive dependency
-- drug_ndc -> drug_brand_generic_code -> drug_brand_generic_desc.
CREATE TABLE dim_brand_generic (
    drug_brand_generic_code   INT           NOT NULL,
    drug_brand_generic_desc   VARCHAR(10)   NOT NULL,
    PRIMARY KEY (drug_brand_generic_code)
);

-- dim_drug — PK drug_ndc (natural key, FDA National Drug Code)
CREATE TABLE dim_drug (
    drug_ndc                  INT            NOT NULL,
    drug_name                 VARCHAR(100)   NOT NULL,
    drug_form_code            CHAR(2)        NOT NULL,
    drug_brand_generic_code   INT            NOT NULL,
    PRIMARY KEY (drug_ndc)
);

-- ------------------------------------------------------------
-- Fact table
-- ------------------------------------------------------------
-- fact_prescription — PK prescription_id (surrogate key)
-- No single natural column uniquely identifies a fill event
-- (a member can fill the same drug on multiple dates), so a
-- surrogate key is used instead of a bulky composite key.
-- Grain: one row = one prescription fill event
--        (one member, one drug, one fill date).
-- Measures: copay and insurance_paid are both fully ADDITIVE.
CREATE TABLE fact_prescription (
    prescription_id   INT   NOT NULL AUTO_INCREMENT,
    member_id         INT   NOT NULL,
    drug_ndc          INT   NOT NULL,
    fill_date         DATE  NOT NULL,
    copay             INT   NOT NULL,
    insurance_paid    INT   NOT NULL,
    PRIMARY KEY (prescription_id)
);

-- ------------------------------------------------------------
-- Load data
-- ------------------------------------------------------------
-- NOTE: paths are RELATIVE to the /data folder of this repo.
-- Depending on your MySQL setup you may need:
--   SET GLOBAL local_infile = 1;   -- on the server
-- and to start the client with --local-infile=1.
-- Adjust the path prefix to wherever you cloned the repo.

LOAD DATA LOCAL INFILE 'data/dim_member.csv'
INTO TABLE dim_member
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(member_id, member_first_name, member_last_name, member_birth_date, member_age, member_gender);

LOAD DATA LOCAL INFILE 'data/dim_drug_form.csv'
INTO TABLE dim_drug_form
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(drug_form_code, drug_form_desc);

LOAD DATA LOCAL INFILE 'data/dim_brand_generic.csv'
INTO TABLE dim_brand_generic
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(drug_brand_generic_code, drug_brand_generic_desc);

LOAD DATA LOCAL INFILE 'data/dim_drug.csv'
INTO TABLE dim_drug
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(drug_ndc, drug_name, drug_form_code, drug_brand_generic_code);

LOAD DATA LOCAL INFILE 'data/fact_prescription.csv'
INTO TABLE fact_prescription
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(prescription_id, member_id, drug_ndc, fill_date, copay, insurance_paid);

-- ------------------------------------------------------------
-- Foreign keys (added after load to avoid load-order errors)
-- ------------------------------------------------------------

-- dim_drug -> dim_drug_form
-- RESTRICT on delete (don't orphan drugs); CASCADE on update (propagate code fixes)
ALTER TABLE dim_drug
ADD CONSTRAINT fk_drug_form
FOREIGN KEY (drug_form_code) REFERENCES dim_drug_form(drug_form_code)
ON DELETE RESTRICT ON UPDATE CASCADE;

-- dim_drug -> dim_brand_generic
ALTER TABLE dim_drug
ADD CONSTRAINT fk_brand_generic
FOREIGN KEY (drug_brand_generic_code) REFERENCES dim_brand_generic(drug_brand_generic_code)
ON DELETE RESTRICT ON UPDATE CASCADE;

-- fact_prescription -> dim_member
-- CASCADE on delete (member removed -> their fills go too); CASCADE on update
ALTER TABLE fact_prescription
ADD CONSTRAINT fk_member
FOREIGN KEY (member_id) REFERENCES dim_member(member_id)
ON DELETE CASCADE ON UPDATE CASCADE;

-- fact_prescription -> dim_drug
-- RESTRICT on delete (preserve fill history for audit/compliance); CASCADE on update
ALTER TABLE fact_prescription
ADD CONSTRAINT fk_drug
FOREIGN KEY (drug_ndc) REFERENCES dim_drug(drug_ndc)
ON DELETE RESTRICT ON UPDATE CASCADE;
