-- Step 3: sql/queries.sql
CREATE OR REPLACE TABLE el AS SELECT * FROM 'data/processed/electricity.parquet';
-- Q1: mean and peak consumption by year, with growth against the year before (LAG)
SELECT year, AVG(consumption) AS mean_mwh, MAX(consumption) AS peak_mwh, 100.0 * (AVG(consumption) / LAG(AVG(consumption)) OVER (ORDER BY year) - 1) AS growth_pct FROM el GROUP BY 1 ORDER BY 1;
-- Q2: profile of the day on working days, weekends and public holidays
SELECT CASE WHEN holiday = 1 THEN 'holiday' WHEN weekend = 1 THEN 'weekend' ELSE 'working day' END AS day_type, hour, AVG(consumption) AS mean_mwh FROM el GROUP BY 1, 2 ORDER BY 1, 2;
-- Q3: consumption against temperature in bands of 5 degrees: heating on the left, cooling on the right
SELECT FLOOR(temperature / 5) * 5 AS temp_band, COUNT(*) AS hours, AVG(consumption) AS mean_mwh, RANK() OVER (ORDER BY AVG(consumption) DESC) AS rank FROM el GROUP BY 1 HAVING COUNT(*) > 100 ORDER BY 1;
-- Q4: model table; the target is the consumption 24 hours ahead; the calendar of the target hour is known in advance, the weather of the target hour is kept only for the upper-bound test
CREATE OR REPLACE TABLE feat AS
WITH b AS (SELECT time, year, consumption, temperature, humidity, cloud, wind, rain,
             LEAD(consumption, 24) OVER w AS y, LEAD(time, 24) OVER w AS target_time, LEAD(holiday, 24) OVER w AS holiday, LEAD(temperature, 24) OVER w AS temp_at_target,
             LAG(consumption, 1) OVER w AS cons_1h, LAG(consumption, 24) OVER w AS cons_yesterday, LAG(consumption, 144) OVER w AS same_hour_last_week,
             AVG(consumption) OVER (ORDER BY time ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) AS mean_24h, AVG(consumption) OVER (ORDER BY time ROWS BETWEEN 167 PRECEDING AND CURRENT ROW) AS mean_7d,
             AVG(temperature) OVER (ORDER BY time ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) AS temp_mean_24h
      FROM el WINDOW w AS (ORDER BY time))
SELECT *, year(target_time) AS target_year, hour(target_time) AS hour, dayofweek(target_time) AS dow, CASE WHEN dayofweek(target_time) IN (0, 6) THEN 1 ELSE 0 END AS weekend,
       SIN(2 * PI() * dayofyear(target_time) / 365.25) AS season_sin, COS(2 * PI() * dayofyear(target_time) / 365.25) AS season_cos
FROM b WHERE y IS NOT NULL AND same_hour_last_week IS NOT NULL;
SELECT target_year, COUNT(*) AS n, AVG(y) AS mean_target, SUM(holiday) AS holiday_hours FROM feat GROUP BY 1 ORDER BY 1;
