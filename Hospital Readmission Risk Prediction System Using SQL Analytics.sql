-- Set the correct database context
USE HealthcareAnalytics;
GO

-- Now your queries will work correctly
SELECT * FROM healthcare_dataset;



SELECT COLUMN_NAME 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'healthcare_dataset';

--check for missing values--

SELECT 
    SUM(CASE WHEN Name IS NULL THEN 1 ELSE 0 END) AS Missing_Name,
    SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS Missing_Age,
    SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS Missing_Gender,
    SUM(CASE WHEN Blood_Type IS NULL THEN 1 ELSE 0 END) AS Missing_Blood_Type,
    SUM(CASE WHEN Medical_Condition IS NULL THEN 1 ELSE 0 END) AS Missing_Medical_Condition,
    SUM(CASE WHEN Date_of_Admission IS NULL THEN 1 ELSE 0 END) AS Missing_Date_of_Admission,
    SUM(CASE WHEN Doctor IS NULL THEN 1 ELSE 0 END) AS Missing_Doctor,
    SUM(CASE WHEN Hospital IS NULL THEN 1 ELSE 0 END) AS Missing_Hospital,
    SUM(CASE WHEN Insurance_Provider IS NULL THEN 1 ELSE 0 END) AS Missing_Insurance_Provider,
    SUM(CASE WHEN Billing_Amount IS NULL THEN 1 ELSE 0 END) AS Missing_Billing_Amount,
    SUM(CASE WHEN Room_Number IS NULL THEN 1 ELSE 0 END) AS Missing_Room_Number,
    SUM(CASE WHEN Admission_Type IS NULL THEN 1 ELSE 0 END) AS Missing_Admission_Type,
    SUM(CASE WHEN Discharge_Date IS NULL THEN 1 ELSE 0 END) AS Missing_Discharge_Date,
    SUM(CASE WHEN Medication IS NULL THEN 1 ELSE 0 END) AS Missing_Medication,
    SUM(CASE WHEN Test_Results IS NULL THEN 1 ELSE 0 END) AS Missing_Test_Results
FROM healthcare_dataset;

--Replace Missing Billing Amount with the Average--

UPDATE healthcare_dataset  
SET Billing_Amount = (SELECT AVG(Billing_Amount) FROM healthcare_dataset)  
WHERE Billing_Amount IS NULL;



-- 1.  identify readmissions within 30 days
WITH patient_admissions AS (
  SELECT 
    Name,
    Date_of_Admission AS current_admission,
    Discharge_Date AS current_discharge,
    Medical_Condition,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission
  FROM healthcare_dataset
)

SELECT * FROM patient_admissions
WHERE days_until_readmission > 0 AND days_until_readmission <= 30;

-- 2. Readmission rates by medical condition with rounded percentages
WITH patient_readmissions AS (
  SELECT 
    Name,
    Medical_Condition,
    Date_of_Admission,
    Discharge_Date,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS is_readmission
  FROM healthcare_dataset
)

SELECT 
  Medical_Condition,
  COUNT(*) AS total_admissions,
  SUM(is_readmission) AS readmissions,
  ROUND(CAST(SUM(is_readmission) AS FLOAT) / COUNT(*) * 100, 2) AS readmission_rate_percent
FROM patient_readmissions
GROUP BY Medical_Condition
ORDER BY readmission_rate_percent DESC;

-- 3. Analyze readmission rates by age group with rounded percentages
WITH patient_readmissions AS (
  SELECT 
    Name,
    Age,
    Date_of_Admission,
    Discharge_Date,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS is_readmission
  FROM healthcare_dataset
)

SELECT 
  CASE 
    WHEN Age < 18 THEN 'Under 18'
    WHEN Age BETWEEN 18 AND 35 THEN '18-35'
    WHEN Age BETWEEN 36 AND 50 THEN '36-50'
    WHEN Age BETWEEN 51 AND 65 THEN '51-65'
    WHEN Age BETWEEN 66 AND 80 THEN '66-80'
    ELSE 'Over 80'
  END AS age_group,
  COUNT(*) AS total_patients,
  SUM(is_readmission) AS readmissions,
  ROUND(CAST(SUM(is_readmission) AS FLOAT) / COUNT(*) * 100, 2) AS readmission_rate_percent
FROM patient_readmissions
GROUP BY CASE 
    WHEN Age < 18 THEN 'Under 18'
    WHEN Age BETWEEN 18 AND 35 THEN '18-35'
    WHEN Age BETWEEN 36 AND 50 THEN '36-50'
    WHEN Age BETWEEN 51 AND 65 THEN '51-65'
    WHEN Age BETWEEN 66 AND 80 THEN '66-80'
    ELSE 'Over 80'
  END
ORDER BY readmission_rate_percent DESC;


-- 4. Length of stay impact on readmissions
WITH patient_readmissions AS (
  SELECT 
    Name,
    Date_of_Admission,
    Discharge_Date,
    DATEDIFF(DAY, Date_of_Admission, Discharge_Date) AS length_of_stay,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS is_readmission
  FROM healthcare_dataset
)

SELECT 
  CASE 
    WHEN length_of_stay < 3 THEN 'Less than 3 days'
    WHEN length_of_stay BETWEEN 3 AND 7 THEN '3-7 days'
    WHEN length_of_stay BETWEEN 8 AND 14 THEN '8-14 days'
    WHEN length_of_stay BETWEEN 15 AND 21 THEN '15-21 days'
    ELSE 'More than 21 days'
  END AS stay_length_group,
  COUNT(*) AS total_admissions,
  SUM(is_readmission) AS readmissions,
  ROUND(CAST(SUM(is_readmission) AS FLOAT) / COUNT(*) * 100, 2) AS readmission_rate_percent
FROM patient_readmissions
GROUP BY CASE 
    WHEN length_of_stay < 3 THEN 'Less than 3 days'
    WHEN length_of_stay BETWEEN 3 AND 7 THEN '3-7 days'
    WHEN length_of_stay BETWEEN 8 AND 14 THEN '8-14 days'
    WHEN length_of_stay BETWEEN 15 AND 21 THEN '15-21 days'
    ELSE 'More than 21 days'
  END
ORDER BY readmission_rate_percent DESC;

-- 5. Readmission rates by admission type
WITH patient_readmissions AS (
  SELECT 
    Name,
    Admission_Type,
    Date_of_Admission,
    Discharge_Date,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS is_readmission
  FROM healthcare_dataset
)

SELECT 
  Admission_Type,
  COUNT(*) AS total_admissions,
  SUM(is_readmission) AS readmissions,
  ROUND(CAST(SUM(is_readmission) AS FLOAT) / COUNT(*) * 100, 2) AS readmission_rate_percent
FROM patient_readmissions
GROUP BY Admission_Type
ORDER BY readmission_rate_percent DESC;

-- 6. Readmission rates by insurance provider
WITH patient_readmissions AS (
  SELECT 
    Name,
    Insurance_Provider,
    Date_of_Admission,
    Discharge_Date,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS is_readmission
  FROM healthcare_dataset
)

SELECT 
  Insurance_Provider,
  COUNT(*) AS total_admissions,
  SUM(is_readmission) AS readmissions,
  ROUND(CAST(SUM(is_readmission) AS FLOAT) / COUNT(*) * 100, 2) AS readmission_rate_percent
FROM patient_readmissions
GROUP BY Insurance_Provider
ORDER BY readmission_rate_percent DESC;

-- 7. Readmission rates by medication
WITH patient_readmissions AS (
  SELECT 
    Name,
    Medication,
    Date_of_Admission,
    Discharge_Date,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS is_readmission
  FROM healthcare_dataset
)

SELECT 
  Medication,
  COUNT(*) AS total_prescriptions,
  SUM(is_readmission) AS readmissions,
  ROUND(CAST(SUM(is_readmission) AS FLOAT) / COUNT(*) * 100, 2) AS readmission_rate_percent
FROM patient_readmissions
GROUP BY Medication
ORDER BY readmission_rate_percent DESC;

-- 8. Readmission rates by test results
WITH patient_readmissions AS (
  SELECT 
    Name,
    Test_Results,
    Date_of_Admission,
    Discharge_Date,
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS is_readmission
  FROM healthcare_dataset
)

SELECT 
  Test_Results,
  COUNT(*) AS total_tests,
  SUM(is_readmission) AS readmissions,
  ROUND(CAST(SUM(is_readmission) AS FLOAT) / COUNT(*) * 100, 2) AS readmission_rate_percent
FROM patient_readmissions
GROUP BY Test_Results
ORDER BY readmission_rate_percent DESC;

-- 9. Comprehensive multifactor readmission risk prediction model (updated)
WITH patient_risk_factors AS (
  SELECT 
    Name,
    Age,
    Medical_Condition,
    Admission_Type,
    Insurance_Provider,
    Medication,
    Test_Results,
    DATEDIFF(DAY, Date_of_Admission, Discharge_Date) AS length_of_stay,
    Date_of_Admission,
    Discharge_Date,
    -- Calculate individual risk scores based on our findings
    CASE 
      WHEN Medical_Condition = 'Asthma' THEN 35
      WHEN Medical_Condition = 'Obesity' THEN 31
      WHEN Medical_Condition = 'Diabetes' THEN 25
      WHEN Medical_Condition = 'Arthritis' THEN 18
      WHEN Medical_Condition = 'Hypertension' THEN 12
      WHEN Medical_Condition = 'Cancer' THEN 6
      ELSE 0
    END AS condition_risk,
    
    CASE
      WHEN Insurance_Provider = 'Aetna' THEN 35
      WHEN Insurance_Provider = 'UnitedHealthcare' THEN 25
      WHEN Insurance_Provider = 'Cigna' THEN 20
      WHEN Insurance_Provider = 'Blue Cross' THEN 15
      WHEN Insurance_Provider = 'Medicare' THEN 10
      ELSE 0
    END AS insurance_risk,
    
    CASE
      WHEN Admission_Type = 'Emergency' THEN 33
      WHEN Admission_Type = 'Urgent' THEN 18
      WHEN Admission_Type = 'Elective' THEN 12
      ELSE 0
    END AS admission_type_risk,
    
    CASE
      WHEN Age BETWEEN 51 AND 65 THEN 31
      WHEN Age BETWEEN 18 AND 35 THEN 26
      WHEN Age BETWEEN 36 AND 50 THEN 19
      WHEN Age BETWEEN 66 AND 80 THEN 13
      ELSE 0
    END AS age_risk,
    
    CASE
      WHEN Medication = 'Lipitor' THEN 30
      WHEN Medication IN ('Paracetamol', 'Aspirin', 'Ibuprofen') THEN 20
      WHEN Medication = 'Penicillin' THEN 14
      ELSE 0
    END AS medication_risk,
    
    CASE
      WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) BETWEEN 15 AND 21 THEN 30
      WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) > 21 THEN 27
      WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) BETWEEN 3 AND 7 THEN 18
      WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) < 3 THEN 16
      WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) BETWEEN 8 AND 14 THEN 9
      ELSE 0
    END AS length_of_stay_risk,
    
    CASE
      WHEN Test_Results = 'Abnormal' THEN 29
      WHEN Test_Results = 'Inconclusive' THEN 24
      WHEN Test_Results = 'Normal' THEN 9
      ELSE 0
    END AS test_results_risk,
    
    -- Track if this patient was readmitted within 30 days (for validation)
    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
    DATEDIFF(DAY, 
      Discharge_Date,
      LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
    ) AS days_until_readmission,
    CASE WHEN 
      DATEDIFF(DAY, 
        Discharge_Date,
        LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
      ) BETWEEN 1 AND 30
    THEN 1 ELSE 0 END AS was_readmitted
  FROM healthcare_dataset
)

SELECT 
  Name,
  Medical_Condition,
  Age,
  Admission_Type,
  Insurance_Provider,
  Medication,
  Test_Results,
  length_of_stay,
  -- Calculate total risk score (sum of individual risk factors)
  (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) AS total_risk_score,
  -- Categorize risk
  CASE
    WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 180 THEN 'Very High Risk'
    WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 140 THEN 'High Risk'
    WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 100 THEN 'Moderate Risk'
    WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 60 THEN 'Low Risk'
    ELSE 'Very Low Risk'
  END AS risk_category,
  was_readmitted
FROM patient_risk_factors
ORDER BY total_risk_score DESC;

--Create a stored procedure that automatically runs the risk prediction query--

CREATE PROCEDURE CalculateReadmissionRisk
AS
BEGIN
    -- Create tables if they don't exist
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PatientReadmissionRisk')
    BEGIN
        CREATE TABLE PatientReadmissionRisk (
            ID INT IDENTITY(1,1) PRIMARY KEY,
            PatientName VARCHAR(100),
            MedicalCondition VARCHAR(100),
            Age INT,
            AdmissionType VARCHAR(50),
            InsuranceProvider VARCHAR(100),
            Medication VARCHAR(100),
            TestResults VARCHAR(50),
            LengthOfStay INT,
            TotalRiskScore INT,
            RiskCategory VARCHAR(50),
            CalculationDate DATETIME
        );
    END

    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PatientAlerts')
    BEGIN
        CREATE TABLE PatientAlerts (
            ID INT IDENTITY(1,1) PRIMARY KEY,
            PatientName VARCHAR(100),
            AlertType VARCHAR(50),
            AlertMessage VARCHAR(500),
            CreatedDate DATETIME
        );
    END

    -- Insert risk assessment results into the dedicated table
    -- Note the semicolon before the WITH clause
    ;WITH patient_risk_factors AS (
        SELECT 
            Name,
            Age,
            Medical_Condition,
            Admission_Type,
            Insurance_Provider,
            Medication,
            Test_Results,
            DATEDIFF(DAY, Date_of_Admission, Discharge_Date) AS length_of_stay,
            Date_of_Admission,
            Discharge_Date,
            -- Calculate individual risk scores based on our findings
            CASE 
                WHEN Medical_Condition = 'Asthma' THEN 35
                WHEN Medical_Condition = 'Obesity' THEN 31
                WHEN Medical_Condition = 'Diabetes' THEN 25
                WHEN Medical_Condition = 'Arthritis' THEN 18
                WHEN Medical_Condition = 'Hypertension' THEN 12
                WHEN Medical_Condition = 'Cancer' THEN 6
                ELSE 0
            END AS condition_risk,
            
            CASE
                WHEN Insurance_Provider = 'Aetna' THEN 35
                WHEN Insurance_Provider = 'UnitedHealthcare' THEN 25
                WHEN Insurance_Provider = 'Cigna' THEN 20
                WHEN Insurance_Provider = 'Blue Cross' THEN 15
                WHEN Insurance_Provider = 'Medicare' THEN 10
                ELSE 0
            END AS insurance_risk,
            
            CASE
                WHEN Admission_Type = 'Emergency' THEN 33
                WHEN Admission_Type = 'Urgent' THEN 18
                WHEN Admission_Type = 'Elective' THEN 12
                ELSE 0
            END AS admission_type_risk,
            
            CASE
                WHEN Age BETWEEN 51 AND 65 THEN 31
                WHEN Age BETWEEN 18 AND 35 THEN 26
                WHEN Age BETWEEN 36 AND 50 THEN 19
                WHEN Age BETWEEN 66 AND 80 THEN 13
                ELSE 0
            END AS age_risk,
            
            CASE
                WHEN Medication = 'Lipitor' THEN 30
                WHEN Medication IN ('Paracetamol', 'Aspirin', 'Ibuprofen') THEN 20
                WHEN Medication = 'Penicillin' THEN 14
                ELSE 0
            END AS medication_risk,
            
            CASE
                WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) BETWEEN 15 AND 21 THEN 30
                WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) > 21 THEN 27
                WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) BETWEEN 3 AND 7 THEN 18
                WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) < 3 THEN 16
                WHEN DATEDIFF(DAY, Date_of_Admission, Discharge_Date) BETWEEN 8 AND 14 THEN 9
                ELSE 0
            END AS length_of_stay_risk,
            
            CASE
                WHEN Test_Results = 'Abnormal' THEN 29
                WHEN Test_Results = 'Inconclusive' THEN 24
                WHEN Test_Results = 'Normal' THEN 9
                ELSE 0
            END AS test_results_risk,
            
            -- Track if this patient was readmitted within 30 days
            LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission) AS next_admission,
            DATEDIFF(DAY, 
                Discharge_Date,
                LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
            ) AS days_until_readmission,
            CASE WHEN 
                DATEDIFF(DAY, 
                    Discharge_Date,
                    LEAD(Date_of_Admission) OVER (PARTITION BY Name ORDER BY Date_of_Admission)
                ) BETWEEN 1 AND 30
            THEN 1 ELSE 0 END AS was_readmitted
        FROM healthcare_dataset
    )
    INSERT INTO PatientReadmissionRisk (
        PatientName, 
        MedicalCondition,
        Age,
        AdmissionType,
        InsuranceProvider,
        Medication,
        TestResults,
        LengthOfStay,
        TotalRiskScore,
        RiskCategory,
        CalculationDate
    )
    SELECT 
        Name,
        Medical_Condition,
        Age,
        Admission_Type,
        Insurance_Provider,
        Medication,
        Test_Results,
        length_of_stay,
        (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) AS total_risk_score,
        CASE
            WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 180 THEN 'Very High Risk'
            WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 140 THEN 'High Risk'
            WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 100 THEN 'Moderate Risk'
            WHEN (condition_risk + insurance_risk + admission_type_risk + age_risk + medication_risk + length_of_stay_risk + test_results_risk) >= 60 THEN 'Low Risk'
            ELSE 'Very Low Risk'
        END AS risk_category,
        GETDATE() AS CalculationDate
    FROM patient_risk_factors;
    
    -- Create alerts for high-risk patients
    INSERT INTO PatientAlerts (PatientName, AlertType, AlertMessage, CreatedDate)
    SELECT 
        PatientName, 
        'Readmission Risk', 
        'Patient identified as ' + RiskCategory + ' for 30-day readmission. Consider enhanced follow-up.',
        GETDATE()
    FROM PatientReadmissionRisk
    WHERE RiskCategory IN ('Very High Risk', 'High Risk')
    AND CalculationDate = CAST(GETDATE() AS DATE);
END

EXEC CalculateReadmissionRisk

-- View all risk results
SELECT * FROM PatientReadmissionRisk ORDER BY TotalRiskScore DESC;

-- See risk distribution with rounded percentages
SELECT 
    RiskCategory,
    COUNT(*) AS PatientCount,
    CAST(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM PatientReadmissionRisk), 0) AS INT) AS Percentage
FROM PatientReadmissionRisk
GROUP BY RiskCategory
ORDER BY 
    CASE 
        WHEN RiskCategory = 'Very High Risk' THEN 1
        WHEN RiskCategory = 'High Risk' THEN 2
        WHEN RiskCategory = 'Moderate Risk' THEN 3
        WHEN RiskCategory = 'Low Risk' THEN 4
        ELSE 5
    END;