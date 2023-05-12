create extension postgis;

select * from pg_catalog.pg_extension;

drop table gis_location;
CREATE TABLE gis_location (
    id SERIAL PRIMARY KEY,
    country VARCHAR(50),
    city VARCHAR(50),
    lat NUMERIC(9, 6),
    lon NUMERIC(9, 6),
    population INT
);

select table_name, column_name, data_type from information_schema.columns where table_name='gis_location';


copy gis_location(city, lat, lon, country, population) from '/tmp/worldcities.csv' delimiter ',' csv header;

select * from gis_location limit 10;

-- 1.
-- retrive cities in a specific country
SELECT city, lat, lon
FROM gis_location
WHERE country = 'Canada';

-- Retrieve the city with the highest population in each country
SELECT country, city, lat, lon, population
FROM gis_location
WHERE (country, population) IN (
    SELECT country, MAX(population)
    FROM gis_location
    GROUP BY country
);

-- Retrieve all cities within a certain distance of a specific point
SELECT city, lat, lon
FROM gis_location
WHERE ST_DistanceSphere(ST_SetSRID(ST_MakePoint(-73.9857, 40.7484), 4326), ST_SetSRID(ST_MakePoint(lon, lat), 4326)) < 10000;


-- 2.
-- distance of all the cities from a given points
SELECT city, ST_DistanceSphere(
    ST_SetSRID(ST_MakePoint(-73.9857, 40.7484), 4326),
    ST_SetSRID(ST_MakePoint(lon, lat), 4326)
) AS distance
FROM gis_location;

-- distance between all cities in the gis_location table and a specific city (e.g. "New York") using the ST_DistanceSphere function:
SELECT city, ST_DistanceSphere(
    ST_SetSRID(ST_MakePoint(lon, lat), 4326),
    (SELECT ST_SetSRID(ST_MakePoint(lon, lat), 4326)
     FROM gis_location WHERE city = 'New York')
) AS distance
FROM gis_location;

-- the distance between all cities in the gis_location table that have a population greater than a certain value (e.g. 1 million) using the ST_DistanceSpheroid function:
SELECT city, ST_DistanceSpheroid(
    ST_SetSRID(ST_MakePoint(lon, lat), 4326),
    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
    'SPHEROID["WGS 84",6378137,298.257223563]'
) AS distance
FROM gis_location
WHERE population > 1000000;

-- 3. areas of interest
	-- Find all cities within a certain distance of a given point:
	SELECT city, ST_Distance(
	  ST_SetSRID(ST_MakePoint(lon, lat), 4326),
	  ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326)
	) AS distance
	FROM gis_location
	WHERE ST_DWithin(
	  ST_SetSRID(ST_MakePoint(lon, lat), 4326),
	  ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	  50000
	)
	ORDER BY distance;

	-- Find all cities within a given bounding box:
	SELECT city, lat, lon
	FROM gis_location
	WHERE lon BETWEEN -118.5 AND -117.5
	AND lat BETWEEN 33.5 AND 34.5;

	-- Find all cities within a given polygon:
	SELECT city, lat, lon
	FROM gis_location
	WHERE ST_Contains(
	  ST_SetSRID(
	    ST_MakePolygon(
	      ST_GeomFromText('LINESTRING(-118.2437 34.0522, -118.3 34.05, -118.2 33.9, -118.2437 34.0522)')
	    ),
	    4326
	  ),
	  ST_SetSRID(ST_MakePoint(lon, lat), 4326)
	);

	-- Find all cities with a population above a certain threshold within a certain distance of a given point:
	SELECT city, population, ST_Distance(
	  ST_SetSRID(ST_MakePoint(lon, lat), 4326),
	  ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326)
	) AS distance
	FROM gis_location
	WHERE population > 100000
	AND ST_DWithin(
	  ST_SetSRID(ST_MakePoint(lon, lat), 4326),
	  ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	  50000
	)
	ORDER BY distance;


-- 5. 
	-- Retrieving GIS locations for specific features and sorting by population in descending order:
	SELECT *
	FROM gis_location
	WHERE country = 'United States'
	ORDER BY population DESC;

	-- Retrieving the top 10 most populous cities in the USA:
	SELECT *
	FROM gis_location
	WHERE country = 'United States'
	ORDER BY population DESC
	LIMIT 10;

	-- Retrieving GIS locations within a certain distance from a point, and sorting by distance in ascending order:
	SELECT city, ST_Distance(
    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326)
	) AS distance
	FROM gis_location
	WHERE country = 'United States' AND ST_Distance(
	    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326)
	) < 500000
	ORDER BY distance ASC;

	-- Retrieving the 5 closest cities to a specific point:
	SELECT city, ST_Distance(
    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326)
	) AS distance
	FROM gis_location
	WHERE country = 'United States' AND ST_Distance(
	    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326)
	) < 500000
	ORDER BY distance ASC
	LIMIT 5;

-- 6. optimizing 
	-- creating spatial index on lon and lat 
	CREATE INDEX gis_location_geom_idx ON gis_location USING GIST (ST_SetSRID(ST_MakePoint(lon, lat), 4326));
	SELECT city, ST_Distance(
	    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326)
	) AS distance
	FROM gis_location
	WHERE country = 'United States' AND
	    ST_DWithin(
	        ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	       	ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326),
	        500000
	    )
	ORDER BY distance ASC
	LIMIT 5;

	-- Use a smaller bounding box to limit the search space:
	SELECT city, ST_Distance(
	    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326)
	) AS distance
	FROM gis_location
	WHERE country = 'United States' AND
	    lon BETWEEN -77 AND -76 AND
	    lat BETWEEN 38 AND 39 AND
	    ST_DWithin(
	        ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	        ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326),
	        500000
	    )
	ORDER BY distance ASC
	LIMIT 5;

	-- Use the ST_DWithin function instead of ST_Distance:
	SELECT city
	FROM gis_location
	WHERE ST_DWithin(
	    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326),
	    500000
	) AND country = 'United States'
	ORDER BY ST_Distance(
	    ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326),
	    ST_SetSRID(ST_MakePoint(gis_location.lon, gis_location.lat), 4326)
	) ASC
	LIMIT 5;



-- 7 N-optimization
	-- create spatial index
	CREATE INDEX gis_location_geom_idx ON gis_location USING GIST (ST_SetSRID(ST_MakePoint(lon, lat), 4326));
	
	-- Use filters to narrow down the search space:
	SELECT city, population
	FROM gis_location
	WHERE country = 'United States' AND population > 1000000
	ORDER BY population DESC
	LIMIT 10;

	-- Use subqueries to break down complex queries:
	SELECT city, population
	FROM (
	  SELECT city, population,
	    ST_Distance(
	      ST_SetSRID(ST_MakePoint(lon, lat), 4326),
	      ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326)
	    ) AS distance
	  FROM gis_location
	  WHERE country = 'United States'
	) AS subquery
	WHERE distance < 50000
	ORDER BY population DESC
	LIMIT 10;

	-- Use aggregates to summarize data:
	SELECT country, COUNT(*) AS num_cities, AVG(population) AS avg_population
	FROM gis_location
	GROUP BY country
	ORDER BY num_cities DESC;

	-- Use LIMIT and OFFSET to paginate results:
	select * from gis_location order by population desc limit 20 offset 40;

	-- Use EXPLAIN to analyze query performance:
	EXPLAIN ANALYZE SELECT city, population
	FROM gis_location
	WHERE country = 'USA' AND population > 1000000
	ORDER BY population DESC
	LIMIT 10;





