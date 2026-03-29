-- Clean and standardize NYC Open Restaurant Applications data
-- One row per restaurant application

WITH source AS (
    SELECT * FROM {{ source('raw_restaurants', 'source_nyc_open_restaurant_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
    SELECT
        -- Get all columns from source, except ones we're transforming below
        * EXCEPT (
            objectid,
            time_of_submission,
            restaurant_name,
            doing_business_as_dba,
            legal_business_name,
            business_address,
            street,
            bulding_number,
            borough,
            zip,
            seating_interest_sidewalk,
            approved_for_sidewalk_seating,
            approved_for_roadway_seating,
            latitude,
            longitude
        ),

        -- Identifiers
        CAST(objectid AS STRING) AS application_id,

        -- Date/Time
        CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,

        -- Restaurant details
        UPPER(TRIM(CAST(restaurant_name AS STRING))) AS restaurant_name,
        UPPER(TRIM(CAST(doing_business_as_dba AS STRING))) AS doing_business_as_dba,
        UPPER(TRIM(CAST(legal_business_name AS STRING))) AS legal_business_name,

        -- Address fields
        CAST(business_address AS STRING) AS business_address,
        CAST(street AS STRING) AS street,
        CAST(bulding_number AS STRING) AS building_number, -- renamed to fix source typo

        -- Location - standardize borough
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Location - clean zip code, handling common zip code data problems
        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA') THEN NULL
            WHEN UPPER(TRIM(CAST(zip AS STRING))) = 'ANONYMOUS' THEN NULL
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 5 THEN TRIM(CAST(zip AS STRING))
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 9 THEN TRIM(CAST(zip AS STRING))
            WHEN LENGTH(TRIM(CAST(zip AS STRING))) = 10
                AND REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{5}-\d{4}')
            THEN TRIM(CAST(zip AS STRING))
            ELSE NULL
        END AS zip,

        -- Seating details
        UPPER(TRIM(CAST(seating_interest_sidewalk AS STRING))) AS seating_interest_sidewalk,
        UPPER(TRIM(CAST(approved_for_sidewalk_seating AS STRING))) AS approved_for_sidewalk_seating,
        UPPER(TRIM(CAST(approved_for_roadway_seating AS STRING))) AS approved_for_roadway_seating,

        -- Coordinates
        CAST(latitude AS DECIMAL) AS latitude,
        CAST(longitude AS DECIMAL) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE objectid IS NOT NULL
    AND time_of_submission IS NOT NULL

    -- Deduplicate on objectid, keeping most recent submission
    QUALIFY ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY time_of_submission DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table: stg_nyc_open_restaurant_apps


