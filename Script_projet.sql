WITH 
GeolocAverage AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS avg_lat,
        AVG(geolocation_lng) AS avg_lng
    FROM 
        geoloc
    GROUP BY 
        geolocation_zip_code_prefix
),
Profile AS (
    SELECT 
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        ga.avg_lat AS geolocation_lat,
        ga.avg_lng AS geolocation_lng,
        MIN(o.order_purchase_timestamp) AS FirstOrderDate
    FROM 
        customers c
    INNER JOIN 
        orders o ON c.customer_id = o.customer_id
    LEFT JOIN 
        GeolocAverage ga ON c.customer_zip_code_prefix = ga.geolocation_zip_code_prefix
    GROUP BY 
        c.customer_unique_id
),
Recency AS (
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS LastOrderDate
    FROM 
        customers c
    INNER JOIN 
        orders o ON c.customer_id = o.customer_id
    WHERE 
        o.order_status NOT IN ('cancelled', 'unavailable')
    GROUP BY 
        c.customer_unique_id
),
Frequency AS (
    SELECT 
        c.customer_unique_id, 
        COUNT(o.order_id) AS TotalOrders
    FROM 
        customers c
    INNER JOIN 
        orders o ON c.customer_id = o.customer_id
    WHERE 
        o.order_status NOT IN ('cancelled', 'unavailable')
    GROUP BY 
        c.customer_unique_id
),
Monetary AS (
    SELECT 
        c.customer_unique_id, 
        SUM(oi.price) AS TotalSpent,
        SUM(oi.freight_value) AS TotalFreight
    FROM 
        customers c
    JOIN 
        orders o ON c.customer_id = o.customer_id
    JOIN 
        order_items oi ON o.order_id = oi.order_id
    WHERE 
        o.order_status NOT IN ('cancelled', 'unavailable')
    GROUP BY 
        c.customer_unique_id
),
Satisfaction AS (
    SELECT 
        c.customer_unique_id, 
        AVG(r.review_score) AS AverageReviewScore,
        COUNT(r.review_id) AS NumberOfReviews,
        COUNT(r.review_comment_title) AS NumberOfCommentTitles,
        COUNT(r.review_comment_message) AS NumberOfComments
    FROM 
        customers c
    JOIN 
        orders o ON c.customer_id = o.customer_id
    JOIN 
        order_reviews r ON o.order_id = r.order_id
    WHERE 
        o.order_status NOT IN ('cancelled', 'unavailable')
    GROUP BY 
        c.customer_unique_id
),
CustomerCategories AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT p.product_category_name) AS DifferentCategories,
        MAX(p.product_weight_g) AS MaxWeight
    FROM 
        customers c
    JOIN 
        orders o ON c.customer_id = o.customer_id
    JOIN 
        order_items oi ON oi.order_id = o.order_id
    JOIN 
        products p ON p.product_id = oi.product_id
    WHERE 
        o.order_status NOT IN ('cancelled', 'unavailable')
    GROUP BY 
        c.customer_unique_id
),
AverageItemsPerOrder AS (
    SELECT 
        c.customer_unique_id,
        item_count,
        AVG(item_count) AS AvgItems
    FROM (
        SELECT 
            o.customer_id, 
            o.order_id, 
            COUNT(oi.order_item_id) AS item_count
        FROM 
            orders o
        JOIN 
            order_items oi ON o.order_id = oi.order_id
        WHERE 
            o.order_status NOT IN ('cancelled', 'unavailable')
        GROUP BY 
            o.order_id
    ) AS OrderItems
    JOIN customers c ON OrderItems.customer_id = c.customer_id
    GROUP BY 
        c.customer_unique_id
)
SELECT 
    r.customer_unique_id,
    p.customer_city,
    p.customer_state,
    p.geolocation_lat,
    p.geolocation_lng,
    p.FirstOrderDate,
    r.LastOrderDate,
    f.TotalOrders,
    m.TotalSpent,
    m.TotalFreight,
    a.AvgItems,
    a.item_count,
    s.AverageReviewScore,
    s.NumberOfReviews,
    s.NumberOfCommentTitles,
    s.NumberOfComments,
    c.DifferentCategories,
    c.MaxWeight
FROM Recency r
JOIN Profile p ON r.customer_unique_id = p.customer_unique_id
JOIN Frequency f ON r.customer_unique_id = f.customer_unique_id
JOIN Monetary m ON r.customer_unique_id = m.customer_unique_id
LEFT JOIN Satisfaction s ON r.customer_unique_id = s.customer_unique_id
JOIN CustomerCategories c ON r.customer_unique_id = c.customer_unique_id
JOIN AverageItemsPerOrder a ON r.customer_unique_id = a.customer_unique_id;
