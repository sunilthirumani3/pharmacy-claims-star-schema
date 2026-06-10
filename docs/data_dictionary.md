# Data Dictionary

Star schema: one fact table (`fact_prescription`) surrounded by four conformed dimensions.

## fact_prescription
Grain: **one row = one prescription fill event** (one member, one drug, one date).

| Column | Type | Key | Description |
|---|---|---|---|
| prescription_id | INT | PK (surrogate) | Unique fill-event identifier |
| member_id | INT | FK → dim_member | Patient who filled the prescription |
| drug_ndc | INT | FK → dim_drug | FDA National Drug Code of the drug filled |
| fill_date | DATE | | Date the prescription was filled |
| copay | INT | measure (additive) | Amount paid by the patient |
| insurance_paid | INT | measure (additive) | Amount paid by the insurance plan |

## dim_member
| Column | Type | Key | Description |
|---|---|---|---|
| member_id | INT | PK (natural) | PBM-assigned patient ID |
| member_first_name | VARCHAR(100) | | First name |
| member_last_name | VARCHAR(100) | | Last name |
| member_birth_date | DATE | | Date of birth |
| member_age | INT | | Age in years |
| member_gender | CHAR(1) | | M / F |

## dim_drug
| Column | Type | Key | Description |
|---|---|---|---|
| drug_ndc | INT | PK (natural) | FDA National Drug Code |
| drug_name | VARCHAR(100) | | Drug name |
| drug_form_code | CHAR(2) | FK → dim_drug_form | Administration form code |
| drug_brand_generic_code | INT | FK → dim_brand_generic | Brand vs. generic code |

## dim_drug_form
| Column | Type | Key | Description |
|---|---|---|---|
| drug_form_code | CHAR(2) | PK (natural) | Form code (e.g., TB) |
| drug_form_desc | VARCHAR(100) | | Description (e.g., Tablet) |

## dim_brand_generic
| Column | Type | Key | Description |
|---|---|---|---|
| drug_brand_generic_code | INT | PK (natural) | 1 = Generic, 2 = Brand |
| drug_brand_generic_desc | VARCHAR(10) | | Generic / Brand |

## Normalization note
The source was a denormalized flat file with repeating fill groups
(`fill_date1..3`, `copay1..3`, `insurancepaid1..3`), violating 1NF. It was
unpivoted into the fact table and the descriptive code attributes were split
into their own dimensions to eliminate transitive dependencies
(`drug_ndc → code → description`), satisfying 3NF.
