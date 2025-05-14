USE credit_card;

-- creating table dim_applicant here 
CREATE TABLE dim_applicant(
applicant_id INT,
gender CHAR(1),
own_car CHAR(1),
own_property CHAR(1),
num_children INT,
income_total FLOAT, 
income_type VARCHAR(50),
education_type VARCHAR(50),
family_status VARCHAR(50),
housing_type VARCHAR(50),
birth_date DATE,
employment_date DATE,
has_mobile INT, 
has_work_phone BIT, 
has_phone BIT,
has_email BIT, 
occupation_type VARCHAR(50),
family_members FLOAT)

-- making this primary key for dim_applicant
ALTER TABLE dim_applicant
ADD PRIMARY KEY (applicant_id);

-- inserting the columns from table application_record to dim_applicant
INSERT INTO dim_applicant (
    applicant_id, gender, own_car,own_property, num_children, income_total, income_type, education_type,
    family_status, housing_type, birth_date, employment_date,
    has_mobile, has_work_phone, has_phone, has_email,
    occupation_type, family_members
)
SELECT 
	ID,
	CODE_GENDER,
	FLAG_OWN_CAR,
    FLAG_OWN_REALTY,
    CNT_CHILDREN,
    AMT_INCOME_TOTAL,
    NAME_INCOME_TYPE,
    NAME_EDUCATION_TYPE,
    NAME_FAMILY_STATUS,
    NAME_HOUSING_TYPE,
    DATEADD(DAY, DAYS_BIRTH, GETDATE()),       -- 👈 converts days before today into an actual date
    DATEADD(DAY, DAYS_EMPLOYED, GETDATE()),    -- 👈 same for employment
    FLAG_MOBIL,
    FLAG_WORK_PHONE,
    FLAG_PHONE,
    FLAG_EMAIL,
    OCCUPATION_TYPE,
    CNT_FAM_MEMBERS
FROM application_record;


-- to check if there are nulls 
SELECT applicant_id
FROM dim_applicant
WHERE ISNUMERIC(CAST(applicant_id AS VARCHAR)) = 0;

-- changing the column format to not null 
ALTER TABLE dim_applicant
ALTER COLUMN applicant_id INT NOT NULL;



-- to check if there are duplicates 

SELECT applicant_id, COUNT(*) AS DuplicateCount
FROM dim_applicant
GROUP BY applicant_id
HAVING COUNT(*) > 1;

--removing duplicates from the dim_applicants here 
WITH dupes AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY applicant_id ORDER BY (SELECT NULL)) AS rn
    FROM dim_applicant
)
DELETE FROM dupes
WHERE rn > 1;

-- creating table dim_status.

CREATE TABLE dim_status(
status_code CHAR(1),
status_description VARCHAR(50),
status_category VARCHAR(20))

-- we're manually typing this by understanding application_record and credit_record 
INSERT INTO dim_status (status_code, status_description, status_category)
VALUES 
    ('0', 'On time', 'Good'),
    ('1', '1 month late', 'Late'),
    ('2', '2 months late', 'Late'),
    ('3', '3 months late', 'Late'),
    ('4', '4 months late', 'Late'),
    ('5', '5+ months late', 'Late'),
    ('C', 'Closed', 'Closed'),
    ('X', 'No loan for the month', 'No Credit');

-- changing the column format to not null 
ALTER TABLE dim_status
ALTER COLUMN status_code CHAR(1) NOT NULL;

-- making this primary key for dim_date
ALTER TABLE dim_status
ADD PRIMARY KEY (status_code);

-- creating the date_dim table 
CREATE TABLE dim_date(
date_key INT,
date_value DATE, 
month INT,
year INT,
relative_month INT)

-- we do not have the exact birth date of the customer so here it is like 
WITH months AS (
    SELECT TOP 61 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 61 AS relative_month
    FROM master.dbo.spt_values
)
INSERT INTO dim_date (date_key, date_value, month, year, relative_month)
SELECT 
    YEAR(DATEADD(MONTH, relative_month, GETDATE())) * 100 + MONTH(DATEADD(MONTH, relative_month, GETDATE())) AS date_key,  -- YYYYMM format
    DATEADD(MONTH, relative_month, GETDATE()) AS date_value,  -- Actual date
    MONTH(DATEADD(MONTH, relative_month, GETDATE())) AS month,  -- Month (1 to 12)
    YEAR(DATEADD(MONTH, relative_month, GETDATE())) AS year,  -- Year
    relative_month  -- MONTHS_BALANCE
FROM months;

-- changing the column format to not null 
ALTER TABLE dim_date
ALTER COLUMN date_key INT NOT NULL;

-- making this primary key for dim_date
ALTER TABLE dim_date
ADD PRIMARY KEY (date_key);

CREATE TABLE fact_credit_behavior(
fact_id INT IDENTITY(1,1) PRIMARY KEY, 
application_id INT, 
date_key INT, 
status_code CHAR(1),
status_category VARCHAR(20),
FOREIGN KEY (application_id) REFERENCES dim_applicant(applicant_id),
FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
FOREIGN KEY (status_code) REFERENCES dim_status(status_code)
);

--list of application_id values from credit_record that don’t exist in dim_applicant.
SELECT cr.ID AS application_id
FROM credit_record cr
LEFT JOIN dim_applicant da ON cr.ID = da.applicant_id
WHERE da.applicant_id IS NULL;



INSERT INTO fact_credit_behavior (application_id, date_key, status_code, status_category)
SELECT
    cr.ID AS application_id,
    d.date_key,
    cr.STATUS AS status_code,
    CASE 
        WHEN cr.STATUS IN ('0', '1') THEN 'Good'
        WHEN cr.STATUS IN ('2', '3', '4', '5') THEN 'Late'
        WHEN cr.STATUS = 'C' THEN 'Closed'
        WHEN cr.STATUS = 'X' THEN 'No Credit'
        ELSE 'Unknown'
    END AS status_category
FROM credit_record cr
JOIN dim_date d
    ON cr.MONTHS_BALANCE = d.relative_month;

---  SQL DATA PREPARATION QUERIES  --

--1.APPLICANTS WITH NO CREDIT HISTORY 
--identify applicants who have a status of x(no credit history)
SELECT application_id
FROM fact_credit_behavior
WHERE status_code = 'X'
GROUP BY application_id;
-- let's also count them 
SELECT COUNT(application_id) no_cr_history
FROM fact_credit_behavior
WHERE status_code = 'X'; --145950

--2. PERCENTAGE OF APPLICANTS WITH CLOSED STATUS 
--Calculate the percentage of applicants who have a status of C (closed credit record)
SELECT 
100*COUNT(CASE WHEN status_code = 'C' THEN 1 END)/COUNT(*) AS closed_percentage
FROM fact_credit_behavior;--42

--3. APPLICANTS BY EMPLOYMENT DURATION 
--Group applicants by their employment duration (using DAYS_EMPLOYED from the dim_applicant table) and calculate the number of applicants in each category.
SELECT 
    CASE 
        WHEN DATEDIFF(YEAR, employment_date, GETDATE()) BETWEEN 0 AND 1 THEN '0-1 Year'
        WHEN DATEDIFF(YEAR, employment_date, GETDATE()) BETWEEN 2 AND 2 THEN '1-2 Years'
        WHEN DATEDIFF(YEAR, employment_date, GETDATE()) BETWEEN 3 AND 5 THEN '2-5 Years'
        ELSE '5+ Years'
     END AS employment_duration,
COUNT(fb.application_id) AS num_applicants
FROM fact_credit_behavior fb
JOIN dim_applicant da
    ON fb.application_id = da.applicant_id
GROUP BY 
  CASE 
        WHEN DATEDIFF(YEAR, employment_date, GETDATE()) BETWEEN 0 AND 1 THEN '0-1 Year'
        WHEN DATEDIFF(YEAR, employment_date, GETDATE()) BETWEEN 2 AND 2 THEN '1-2 Years'
        WHEN DATEDIFF(YEAR, employment_date, GETDATE()) BETWEEN 3 AND 5 THEN '2-5 Years'
        ELSE '5+ Years'
    END;

--4.INCOME DISTRIBUTION BY HOUSING TYPE 
-- determine the income distribution for applicants based on their housing type 

SELECT 
    da.housing_type,
    AVG(da.income_total) AS avg_income
FROM fact_credit_behavior fb
JOIN dim_applicant da
    ON fb.application_id = da.applicant_id
GROUP BY da.housing_type;

--5. APPLICANTS BY FAMILY SIZE 
-- find the number of applicants grouped by family size.
SELECT 
	da.family_members,
	COUNT(fb.applicant_id) num_applicants
FROM dim_applicant da
JOIN fact_credit_behavior fb
		ON fb.applicant_id = da.applicant_id
GROUP BY da.family_members
ORDER BY num_applicants


-- 6. INCOME AND FAMILY SIZE CORRELATION 
--Determine if there's a correlation between income and family size
SELECT 
    da.income_total,
    da.family_members
FROM dim_applicant da
ORDER BY da.income_total DESC;

--7.Applicants by Education Level
--Group applicants by their education type and count the number of applicants in each category.
SELECT 
    da.education_type,
    COUNT(fb.applicant_id) AS num_applicants
FROM fact_credit_behavior fb
JOIN dim_applicant da
    ON fb.applicant_id = da.applicant_id
GROUP BY da.education_type;

-- 8. Age Distribution of Applicants
--Group applicants by age range and count how many fall into each group.

SELECT 
    CASE 
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 18 AND 25 THEN '18-25'
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 26 AND 35 THEN '26-35'
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 36 AND 45 THEN '36-45'
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 46 AND 55 THEN '46-55'
        ELSE '55+'
    END AS age_group,
    COUNT(fb.applicant_id) AS num_applicants
FROM fact_credit_behavior fb
JOIN dim_applicant da
    ON fb.applicant_id = da.applicant_id
GROUP BY 
    CASE 
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 18 AND 25 THEN '18-25'
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 26 AND 35 THEN '26-35'
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 36 AND 45 THEN '36-45'
        WHEN DATEDIFF(YEAR, da.birth_date, GETDATE()) BETWEEN 46 AND 55 THEN '46-55'
        ELSE '55+'
 END;

 --9. APPLICANTS WITH HIGHEST INCOME AND FAMILY SIZE 
 -- find the top 5 applicants with the highest income and the largest family size 
 SELECT TOP 5
    da.applicant_id,
    da.income_total,
    da.family_members
FROM dim_applicant da
ORDER BY da.income_total DESC, da.family_members DESC;

--10.APPLICANTS BY MARITAL STATUS 
-- count the number of applicants based on their marital status 
SELECT 
	da.family_status,
	COUNT(fb.applicant_id) AS num_applicant 
FROM dim_applicant da 
JOIN fact_credit_behavior fb
ON da.applicant_id = fb.applicant_id
GROUP BY da.family_status;

--11. Applicants by Gender and Employment Type
--Group applicants by gender and income type and find out how many applicants are in each category

SELECT 
	da.gender, 
	da.income_type, 
	COUNT(fb.application_id) AS num_applicants 
FROM dim_applicant da
JOIN fact_credit_behavior fb 
ON fb.application_id = da.applicant_id 
GROUP BY da.gender, da.income_type
ORDER BY num_applicants DESC;

-- 12. TOP 5 APPLICANTS BY AGE 
-- find the top 5 applicants who are the youngest(based on DAYS_BIRTH)
SELECT 
	TOP 5
    da.applicant_id,
    DATEDIFF(YEAR, da.birth_date, GETDATE()) age
FROM dim_applicant da
ORDER BY age ASC;

--13. Applicants with the Longest Employment Duration
--Identify the top 5 applicants with the longest employment duration.
SELECT 
	TOP 5
    da.applicant_id,
    DATEDIFF(YEAR, da.employment_date, GETDATE())  employment_duration
FROM dim_applicant da
ORDER BY employment_duration DESC;

--14. 14. Applicants by Car Ownership and Family Size
--Find the relationship between car ownership and family size (whether owning a car affects family size).
SELECT 
    da.own_car,
    da.family_members,
    COUNT(fb.application_id) AS num_applicants
FROM fact_credit_behavior fb
JOIN dim_applicant da
    ON fb.application_id = da.applicant_id
GROUP BY da.own_car, da.family_members;

--15. Applicants with No Email and Their Income
--Find applicants who do not have an email (FLAG_EMAIL = 0) and their average income
SELECT 
    ROUND(AVG(da.income_total),2) AS avg_income
FROM dim_applicant da
WHERE da.has_email = 0;
