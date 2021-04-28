/*
Evaluating Schools in Flood Zones, Dar es Salaam
March 31, 2021
Emma Brown and Brooke Laird
*/

/* Creating a table of all schools and universities from polygon and point layer */
CREATE TABLE schools AS
SELECT amenity, st_centroid(way)::geometry(point,4326) as way , name, osm_id FROM planet_osm_polygon
WHERE amenity ILIKE 'school' OR amenity ILIKE 'university'
UNION
SELECT amenity, way, name, osm_id FROM planet_osm_point
WHERE amenity ILIKE 'school' OR amenity ILIKE 'university';

-- changing NULL names to OSM ID
UPDATE schools
SET name = osm_id
WHERE name IS NULL
ORDER BY name ASC;

-- grouping by school name to get rid of duplicates, finding the centroids of schools with multiple buildings
CREATE TABLE school_centroids
AS
SELECT name, amenity, st_centroid(st_union(way))::geometry(point, 4326) as geom
FROM schools
GROUP BY name, amenity;

/*
double checking count:
SELECT DISTINCT name, amenity
FROM schools;
*/
-- update flood projection
SELECT addgeometrycolumn('emmab','flooddissolve','newgeom', 4326 ,'MULTIPOLYGON',2);

UPDATE flooddissolve
SET newgeom = ST_Transform(geom, 4326);

-- adding column "flooded"
ALTER TABLE school_centroids
ADD COLUMN flooded text;

-- updating flooded column if school is in flodded zone
UPDATE school_centroids
SET flooded = 'yes'
FROM flooddissolve
WHERE ST_Intersects(school_centroids.geom, flooddissolve.newgeom);

-- calculating percentage of schools in flooded zones
With tot as (SELECT COUNT(name) AS t
FROM school_centroids)
SELECT COUNT(flooded)/t::real as pctflood
FROM school_centroids, tot
WHERE flooded = 'yes'
GROUP BY flooded, t

SELECT COUNT(flooded) AS n
FROM school_centroids
WHERE flooded = 'yes'
GROUP BY flooded

SELECT COUNT(name)
FROM school_centroids

--change coordinate reference system to UTM because it is easier for dealing with distance and buffers
UPDATE flooddissolve
SET geom = ST_Transform(geom, 32737);

SELECT addgeometrycolumn('brooke','school_centroids','utmgeom',32737,'point',2);

UPDATE school_centroids
SET utmgeom = ST_Transform(geom, 32737);


--now lets see which schools might be impcated if the flooding was more severe
CREATE TABLE floodbuffer_one AS
SELECT st_buffer(geom, 10)::geometry(MultiPolygon,32737) as geom from flooddissolve;

CREATE TABLE floodbuffer_two AS
SELECT st_buffer(geom, 50)::geometry(MultiPolygon,32737) as geom from flooddissolve;

--create new columns in school centroids for new buffers
ALTER TABLE school_centroids
ADD COLUMN flooded_10 text;

ALTER TABLE school_centroids
ADD COLUMN flooded_50 text;

--find schools that sit in flood buffer layer

--schools impacted if flood zone grew by 10m
UPDATE school_centroids
SET flooded_10 = 'yes'
FROM floodbuffer_one
WHERE ST_Intersects(school_centroids.utmgeom, floodbuffer_one.geom);

--schools impacted if flood zone grew by 50m
UPDATE school_centroids
SET flooded_50 = 'yes'
FROM floodbuffer_two
WHERE ST_Intersects(school_centroids.utmgeom, floodbuffer_two.geom);


-- calculating percentage of schools in projected/ future flooding zones
With tot as (SELECT COUNT(name) AS t
FROM school_centroids)
SELECT COUNT(flooded_10)/t::real as pctflood
FROM school_centroids, tot
WHERE flooded_10 = 'yes'
GROUP BY flooded_10, t

With tot as (SELECT COUNT(name) AS t
FROM school_centroids)
SELECT COUNT(flooded_50)/t::real as pctflood
FROM school_centroids, tot
WHERE flooded_50 = 'yes'
GROUP BY flooded_50, t
