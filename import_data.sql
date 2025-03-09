BEGIN;

DROP TABLE IF EXISTS data;
DROP TABLE IF EXISTS vax;
DROP TABLE IF EXISTS symptoms;
DROP TABLE IF EXISTS vaers_data;

CREATE TABLE data(
    VAERS_ID NUMERIC(7),            -- VAERS identification number
    RECVDATE DATE,                  -- Date report was received
    STATE CHAR(2),                  -- State
    AGE_YRS NUMERIC(5, 1),          -- Age in years
    CAGE_YR NUMERIC(3),             -- Calculated age of patient in years
    CAGE_MO NUMERIC(2, 1),          -- Calculated age of patient in months
    SEX CHAR(1),                    -- Sex
    RPT_DATE DATE,                  -- Date form completed
    SYMPTOM_TEXT VARCHAR,           -- Reported symptom text
    DIED CHAR(1),                   -- Died
    DATEDIED DATE,                  -- Date of death
    L_THREAT CHAR(1),               -- Life-threatening illness
    ER_VISIT CHAR(1),               -- Emergency room or doctor visit
    HOSPITAL CHAR(1),               -- Hospitalized
    HOSPDAYS NUMERIC,               -- Number of days hospitalized
    X_STAY CHAR(1),                 -- Prolongation of existing hospitalization
    DISABLE CHAR(1),                -- Disability
    RECOVD CHAR(1),                 -- Recovered
    VAX_DATE DATE,                  -- Vaccination date
    ONSET_DATE DATE,                -- Adverse event onset date
    NUMDAYS NUMERIC(5),             -- Number of days (onset date – vaccination date)
    LAB_DATA VARCHAR,               -- Diagnostic laboratory data
    V_ADMINBY CHAR(3),              -- Type of facility where vaccine was administered
    V_FUNDBY CHAR(3),               -- Type of funds used to purchase vaccines
    OTHER_MEDS VARCHAR,             -- Other medications
    CUR_ILL VARCHAR,                -- Illnesses at time of vaccination
    HISTORY VARCHAR,                -- Chronic or long-standing health conditions
    PRIOR_VAX VARCHAR,              -- Prior vaccination event information
    SPLTTYPE CHAR(25),              -- Manufacturer/immunization project report number
    FORM_VERS NUMERIC(1),           -- VAERS form version 1 or 2
    TODAYS_DATE DATE,               -- Date Form Completed
    BIRTH_DEFECT CHAR(1),           -- Congenital anomaly or birth defect
    OFC_VISIT CHAR(1),              -- Doctor or other healthcare provider office/clinic visit
    ER_ED_VISIT CHAR(1),            -- Emergency room/ department or urgent care
    ALLERGIES VARCHAR,              -- Allergies to medications, food, or other products
    YEAR CHAR(4)                    -- An additional column to record the year
);

CREATE TABLE vax(
    VAERS_ID NUMERIC(7),            -- VAERS identification number
    VAX_TYPE CHAR(15),              -- Administered vaccine type
    VAX_MANU CHAR(40),              -- Vaccine manufacturer
    VAX_LOT CHAR(15),               -- Manufacturer’s vaccine lot
    VAX_DOSE_SERIES CHAR(3),        -- Number of doses administered
    VAX_ROUTE CHAR(6),              -- Vaccination route
    VAX_SITE CHAR(6),               -- Vaccination site
    VAX_NAME CHAR(100),             -- Vaccination name
    YEAR CHAR(4)                    -- An additional column to record the year
);

CREATE TABLE symptoms(
    VAERS_ID NUMERIC(7),            -- VAERS identification number
    SYMPTOM1 CHAR(100),             -- Adverse event MedDRA term 1
    SYMPTOMVERSION1 NUMERIC(4,2),   -- MedDRA dictionary version 1
    SYMPTOM2 CHAR(100),             -- Adverse event MedDRA term 1
    SYMPTOMVERSION2 NUMERIC(4,2),   -- MedDRA dictionary version 2
    SYMPTOM3 CHAR(100),             -- Adverse event MedDRA term 3
    SYMPTOMVERSION3 NUMERIC(4,2),   -- MedDRA dictionary version 3
    SYMPTOM4 CHAR(100),             -- Adverse event MedDRA term 4
    SYMPTOMVERSION4 NUMERIC(4,2),   -- MedDRA dictionary version 4
    SYMPTOM5 CHAR(100),             -- Adverse event MedDRA term 5
    SYMPTOMVERSION5 NUMERIC(4,2),   -- MedDRA dictionary version number 5
    YEAR CHAR(4)                    -- An additional column to record the year
);

\set basepath :'basepath'

DO $$
DECLARE
    full_path TEXT;
    rec RECORD;
BEGIN
    base_path := :'basepath';
    FOR rec IN
        SELECT
            SUBSTRING(pg_ls_dir FROM 1 FOR 4) AS year,
            SUBSTRING(pg_ls_dir FROM 5 FOR LENGTH(pg_ls_dir) - 8) AS category,
            pg_ls_dir AS file_name
        FROM pg_ls_dir(base_path)
    LOOP
        RAISE NOTICE 'Reading file: % ', rec.file_name;

        full_path = base_path || rec.file_name;
        IF rec.category = 'VAERSSYMPTOMS'
        THEN
            -- Copy the data from CSV file into symptoms table
            EXECUTE 'COPY symptoms(vaers_id,symptom1,symptomversion1,symptom2,symptomversion2,symptom3,symptomversion3,symptom4,symptomversion4,symptom5,symptomversion5)
                     FROM ''' || full_path || '''
                     DELIMITER '',''
                     CSV HEADER
                     ENCODING ''LATIN1'' ';

            -- Update year column
            EXECUTE 'UPDATE symptoms
                     SET year = ' || rec.year || '
                     WHERE year IS NULL';

        ELSIF rec.category = 'VAERSVAX'
        THEN
            -- Copy the data from CSV file into vax table
            EXECUTE 'COPY vax(vaers_id,vax_type,vax_manu,vax_lot,vax_dose_series,vax_route,vax_site,vax_name)
                     FROM ''' || full_path || '''
                     DELIMITER '',''
                     CSV HEADER
                     ENCODING ''LATIN1'' ';

            -- Update year column
            EXECUTE 'UPDATE vax
                     SET year = ' || rec.year || '
                     WHERE year IS NULL';

        ELSIF rec.category = 'VAERSDATA'
        THEN
            -- Copy the data from CSV file into data table
            EXECUTE 'COPY data(vaers_id,recvdate,state,age_yrs,cage_yr,cage_mo,sex,rpt_date,symptom_text,died,datedied,l_threat,er_visit,hospital,hospdays,x_stay,disable,recovd,vax_date,onset_date,numdays,lab_data,v_adminby,v_fundby,other_meds,cur_ill,history,prior_vax,splttype,form_vers,todays_date,birth_defect,ofc_visit,er_ed_visit,allergies)
                     FROM ''' || full_path || '''
                     DELIMITER '',''
                     CSV HEADER
                     ENCODING ''LATIN1'' ';

            -- Update year column
            EXECUTE 'UPDATE data
                     SET year = ' || rec.year || '
                     WHERE year IS NULL';

        ELSE
            RAISE NOTICE 'Wrong file: %', rec.file_name;
        END IF;

    END LOOP;

END $$;

END;

-- Create a table to store that used for Data Annotation
CREATE TABLE vaers_data AS
SELECT v.vaers_id,
       v.vax_type,
       v.vax_manu,
       v.year,
       d.symptom_text,
       JSON_AGG(DISTINCT TRIM(spr.symptom)) AS symptom_list
FROM vax v
    INNER JOIN data d ON v.vaers_id = d.vaers_id
    INNER JOIN symptoms s ON v.vaers_id = s.vaers_id
    INNER JOIN (
        SELECT vaers_id, symptom1 AS symptom FROM symptoms WHERE symptom1 IS NOT NULL
        UNION ALL
        SELECT vaers_id, symptom2 AS symptom FROM symptoms WHERE symptom2 IS NOT NULL
        UNION ALL
        SELECT vaers_id, symptom3 AS symptom FROM symptoms WHERE symptom3 IS NOT NULL
        UNION ALL
        SELECT vaers_id, symptom4 AS symptom FROM symptoms WHERE symptom4 IS NOT NULL
        UNION ALL
        SELECT vaers_id, symptom5 AS symptom FROM symptoms WHERE symptom5 IS NOT NULL
    ) AS spr ON v.vaers_id = spr.vaers_id
WHERE v.vax_type = 'COVID19'
      AND v.vax_manu = 'MODERNA'
GROUP BY v.vaers_id, v.vax_type, d.symptom_text, v.year;
