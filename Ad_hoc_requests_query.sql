-- Q1) City level fare and trip summary report.

SELECT 
	c.city_name, 
	count(t.city_id) AS total_trips,
    ROUND(sum(fare_amount) / sum(distance_travelled_km),2) AS avg_fare_per_km,
    ROUND(sum(fare_amount) / count(t.city_id),2) AS avg_fare_per_trip,
	CONCAT(ROUND((COUNT(t.city_id) * 100.0) / SUM(COUNT(t.city_id)) OVER (), 0), ' %') AS pct_contribution_to_total_trips
FROM fact_trips t
JOIN dim_city c
ON t.city_id = c.city_id
GROUP BY c.city_id;

-- Q2) Monthly City level trips target performance report.

WITH monthly_trips AS (
    SELECT 
        city_id, 
        MONTHNAME(date) AS month, 
        COUNT(city_id) AS actual_trips
    FROM trips_db.fact_trips
    GROUP BY city_id, MONTHNAME(date)
)
SELECT 
    c.city_name, 
    mt.month, 
    mt.actual_trips, 
    tg.total_target_trips AS target_trips,
    CASE WHEN mt.actual_trips > tg.total_target_trips THEN "Above Target"
    Else "Below Target"
    End AS performance_status,
    ROUND((mt.actual_trips - tg.total_target_trips) / tg.total_target_trips * 100,2) AS pct_difference
FROM monthly_trips mt
JOIN trips_db.dim_city c ON mt.city_id = c.city_id
JOIN targets_db.monthly_target_trips tg 
    ON tg.city_id = c.city_id
    AND MONTHNAME (tg.month) = mt.month 
ORDER BY c.city_name,  mt.month;


--  Q3) City level report passenger  

WITH city_trip_distribution AS (
    SELECT 
        c.city_name,
        d.trip_count,
        SUM(d.repeat_passenger_count) AS repeat_passenger_count
    FROM dim_repeat_trip_distribution d
    JOIN dim_city c ON d.city_id = c.city_id
    GROUP BY c.city_name, d.trip_count
),
city_total_passengers AS (
    SELECT 
        city_name,
        SUM(repeat_passenger_count) AS total_repeat_passengers
    FROM city_trip_distribution
    GROUP BY city_name
),
percentage_distribution AS (
    SELECT 
        d.city_name,
        d.trip_count,
        ROUND((d.repeat_passenger_count * 100.0 / t.total_repeat_passengers),2) AS percentage
    FROM city_trip_distribution d
    JOIN city_total_passengers t ON d.city_name = t.city_name
)
SELECT 
    city_name,
    MAX(CASE WHEN trip_count = 2 THEN percentage ELSE 0 END) AS "2-Trips",
    MAX(CASE WHEN trip_count = 3 THEN percentage ELSE 0 END) AS "3-Trips",
    MAX(CASE WHEN trip_count = 4 THEN percentage ELSE 0 END) AS "4-Trips",
    MAX(CASE WHEN trip_count = 5 THEN percentage ELSE 0 END) AS "5-Trips",
    MAX(CASE WHEN trip_count = 6 THEN percentage ELSE 0 END) AS "6-Trips",
    MAX(CASE WHEN trip_count = 7 THEN percentage ELSE 0 END) AS "7-Trips",
    MAX(CASE WHEN trip_count = 8 THEN percentage ELSE 0 END) AS "8-Trips",
    MAX(CASE WHEN trip_count = 9 THEN percentage ELSE 0 END) AS "9-Trips",
    MAX(CASE WHEN trip_count = 10 THEN percentage ELSE 0 END) AS "10-Trips"
FROM percentage_distribution
GROUP BY city_name
ORDER BY city_name;

-- Q4) Identify cities with highest and lowest total new passengers

WITH city_rank AS (
    SELECT 
        c.city_name, 
        SUM(ps.new_passengers) AS total_new_passengers,
        RANK() OVER (ORDER BY SUM(ps.new_passengers) DESC) AS city_rank_desc,
        RANK() OVER (ORDER BY SUM(ps.new_passengers) ASC) AS city_rank_asc
    FROM fact_passenger_summary ps
    JOIN dim_city c ON ps.city_id = c.city_id
    GROUP BY c.city_id
)
SELECT 
    city_name, 
    total_new_passengers,
    CASE 
        WHEN city_rank_desc <= 3 THEN 'Top 3'
        WHEN city_rank_asc <= 3 THEN 'Bottom 3'
        ELSE NULL
    END AS city_category
FROM city_rank
WHERE city_rank_desc <= 3 OR city_rank_asc <= 3
ORDER BY total_new_passengers DESC;

-- Q5) Identify month with highest revenue for each city

WITH city_wise_revenue AS (
SELECT 
	city_id,
    SUM(fare_amount) AS total_revenue
FROM fact_trips
GROUP BY city_id
),
monthly_revenue_rank  AS(
SELECT 
	c.city_id,
    c.city_name,
    MONTHNAME(t.date) AS month_name,
    SUM(t.fare_amount) AS monthly_revenue,
    RANK() OVER (PARTITION BY city_name ORDER BY SUM(t.fare_amount) DESC) AS revenue_rank
FROM fact_trips t
JOIN dim_city c
ON t.city_id = c.city_id 
GROUP BY c.city_id, month_name
)
SELECT 
	mr.city_name,
    mr.month_name AS highest_revenue_month,
    monthly_revenue AS revenue,
    ROUND(monthly_revenue / total_revenue * 100,2) AS pct_contribution
FROM city_wise_revenue cr
JOIN monthly_revenue_rank mr
ON cr.city_id = mr.city_id
WHERE revenue_rank = 1;

-- Q6) Repeat passengers rate analysis


WITH montly_repeat_passengers AS(
SELECT
    c.city_id,
    c.city_name, 
	MONTHNAME(ps.month) AS month_name,
	total_passengers,
    repeat_passengers,
    ROUND(repeat_passengers / total_passengers  * 100 , 2)AS montly_repeat_passengers_rate_pct
FROM fact_passenger_summary ps
JOIN dim_city c ON ps.city_id = c.city_id 
),
city_repeat_passengers AS (
SELECT 
    city_id,
    SUM(total_passengers) AS total_passengers,
    SUM(repeat_passengers) AS city_repeat_passengers,
    ROUND(SUM(repeat_passengers) / SUM(total_passengers) * 100, 2) AS city_repeat_passengers_rate_pct
FROM 
    fact_passenger_summary
GROUP BY 
    city_id
)
SELECT 
	mrp.city_name,
    mrp.month_name,
    mrp.total_passengers,
    mrp.repeat_passengers,
    mrp.montly_repeat_passengers_rate_pct,
    crp.city_repeat_passengers_rate_pct
FROM montly_repeat_passengers mrp
JOIN city_repeat_passengers crp
ON mrp.city_id = crp.city_id;

