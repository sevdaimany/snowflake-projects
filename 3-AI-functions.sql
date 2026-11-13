ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "aisql_functions"}}';

USE ROLE tb_analyst;
USE WAREHOUSE tb_analyst_wh;
USE DATABASE tb_101;


-- sentiment
SELECT truck_brand_name,
        COUNT(*) AS total_reviews,
        COUNT_IF(sentiment = 'positive') AS positive_reviews,
        COUNT_IF(sentiment IN ('neutral', 'mixed')) AS neutral_reviews,
        COUNT_IF(sentiment = 'negative') AS negative_reviews
FROM (
    SELECT 
        truck_brand_name,
        AI_SENTIMENT(review):categories[0]:sentiment::STRING AS sentiment
    FROM harmonized.truck_reviews_v
    WHERE language ILIKE '%en%' AND review IS NOT NULL
    limit 5
)
GROUP BY truck_brand_name
ORDER BY total_reviews DESC;


-- classify reviews
WITH classified_reviews AS 
(
    SELECT 
        truck_brand_name,
        AI_CLASSIFY(review, ['Food Quality', 'Pricing', 'Service Experience', 'Staff Behavior']):labels[0]::STRING AS feedback_category
    FROM harmonized.truck_reviews_v
    WHERE language ILIKE '%en%' AND review IS NOT NULL AND LENGTH(review) > 30
    limit 5
)
SELECT truck_brand_name, 
        feedback_category,
        COUNT(*)
FROM classified_reviews
GROUP BY truck_brand_name, feedback_category;


-- insights
SELECT 
    truck_brand_name,
    primary_city,
    LEFT(review, 100) || '...' AS review_preview,
    AI_EXTRACT(text => review,
               responseFormat => {'specific_feedback': 'What specific complaint, problem, or praise does the customer mention?'}
            ):response:specific_feedback::string as specific_feedback
FROM harmonized.truck_reviews_v
WHERE language ILIKE '%en%' AND review IS NOT NULL AND LENGTH(review) > 50
limit 5;


-- summarize
SELECT 
    truck_brand_name,
    AI_SUMMARIZE_AGG(review) AS review_summary
FROM(
    SELECT 
        truck_brand_name,
        review
    FROM harmonized.truck_reviews_v
    LIMIT 5
)
GROUP BY
  truck_brand_name;