# 🧾 **CREDIT RISK DATA WAREHOUSE & SQL ANALYSIS PROJECT**

📌 Project Overview:
This project showcases how to transform raw credit and application data into a star schema-based data warehouse using SQL Server, followed by advanced analytical querying for credit behavior analysis.

The project is inspired by real-world credit scoring systems and includes data modeling, cleaning, transformation, and insight extraction for financial decision-making support.

🧱 Tools & Technologies:
SQL Server (T-SQL) – For data modeling and querying

Power BI (optional) – For future reporting and dashboards

credit_record & application_record – Raw datasets representing applicant info and monthly credit behavior

🎯 Objective:
Design a clean star schema data warehouse from raw financial data

Integrate applicant profiles with credit performance records

Analyze credit history, income patterns, family size, and employment data

Extract meaningful insights using advanced SQL queries

🏗️ Data Modeling:
✅ Dimension Tables
dim_applicant – Applicant demographics, income, and employment data

dim_status – Credit status codes and their meaning (e.g., 'On time', 'Closed')

dim_date – Timeline breakdown using month and year keys

✅ Fact Table:
fact_credit_behavior – Links each applicant to monthly credit behavior, with status codes and categories

🧹 Data Preparation Steps
Extracted & cleaned raw fields from application_record and credit_record

Created surrogate keys and removed duplicates in applicant data

Mapped credit status codes (0–5, C, X) to meaningful labels and categories

Constructed a relative date dimension to interpret monthly credit timeline (MONTHS_BALANCE)

Linked all dimensions to a fact table to enable slicing and dicing of credit behavior

📊 Key SQL Analysis Performed:
Applicants with no credit history (Status = 'X')

% of applicants with closed credit records (Status = 'C')

Employment duration grouping (0-1 yr, 2-5 yrs, etc.)

Income distribution by housing type

Family size distribution of applicants

Correlation between income and family size

Applicants by education level and marital status

Age distribution of applicants

Top 5 earners with largest families

Gender & income type breakdown

Youngest & longest-employed applicants

Impact of car ownership on family size

Average income of applicants with no email access


💡 Why This Project Matters

This project demonstrates:

Strong SQL skills for real-world business and financial use cases

Understanding of data warehousing principles and dimensional modeling

Ability to perform complex joins, date manipulation, and groupings

Analytical thinking applied to credit risk profiling


📁 Dataset Overview
application_record: Contains demographic and financial data of applicants

credit_record: Contains monthly credit status for each applicant

Data source: Open Credit Scoring Dataset (commonly used in ML and BI training).
