
-- Step 3: sql/queries.sql, discharge-curve features per cycle
CREATE OR REPLACE TABLE meas AS SELECT * FROM 'data/processed/meas.parquet';
CREATE OR REPLACE TABLE cyc  AS SELECT * FROM eda;
-- Q1: capacity by cycle and cell
SELECT cell, cycle, capacity, capacity / FIRST(capacity) OVER (PARTITION BY cell ORDER BY cycle) AS soh FROM cyc;
-- Q2: features from the discharge curve
CREATE OR REPLACE TABLE curve AS
SELECT cell, cycle, MAX(t) AS discharge_time, AVG(V) AS V_mean, MAX(T) AS T_max, MIN(V) AS V_min,
       regr_slope(V, t) FILTER (WHERE V BETWEEN 3.4 AND 3.8) AS dV_mid_slope,
       SUM(V * I) AS area_curve
FROM meas GROUP BY 1, 2;
-- Q3: model table
CREATE OR REPLACE TABLE feat AS
SELECT c.cell, c.cycle, c.idx, c.T_amb, c.rul, u.*,
       LAG(u.discharge_time, 5) OVER (PARTITION BY c.cell ORDER BY c.cycle) AS dt_lag5
FROM cyc c JOIN curve u USING (cell, cycle);
SELECT cell, COUNT(*) AS n, MIN(rul), MAX(rul) FROM feat GROUP BY 1;
