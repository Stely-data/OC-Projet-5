-- Select informations client
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
    WHERE 
        o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
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
        AND o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
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
        AND o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
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
        AND o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
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
        AND o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY 
        c.customer_unique_id
),
CustomerProducts AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT p.product_category_name) AS DifferentCategories
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
        AND o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY 
        c.customer_unique_id
),
CustomerOrderDetail AS (
    SELECT 
        c.customer_unique_id,
        SUM(OrderItems.item_count) AS nb_item,
        COUNT(OrderItems.order_id) AS order_count,
        AVG(OrderItems.item_count) AS AvgItems,
        AVG(OrderItems.total_weight) AS AvgWeight,
        AVG(OrderItems.total_volume) AS AvgVolume, 
        AVG(julianday(OrderItems.order_delivered_customer_date) - julianday(OrderItems.order_purchase_timestamp)) AS ActualDeliveryTime,
        AVG(julianday(OrderItems.order_delivered_customer_date) - julianday(OrderItems.order_estimated_delivery_date)) AS DeliveryDelay
    FROM (
        SELECT 
            o.customer_id, 
            o.order_id, 
            COUNT(oi.order_item_id) AS item_count,
            SUM(p.product_weight_g) AS total_weight, 
            SUM(p.product_length_cm * p.product_height_cm * p.product_width_cm) AS total_volume, 
            o.order_purchase_timestamp,
            o.order_estimated_delivery_date,
            o.order_delivered_customer_date
        FROM 
            orders o
        JOIN 
            order_items oi ON o.order_id = oi.order_id
        JOIN 
            products p ON oi.product_id = p.product_id 
        WHERE 
            o.order_status NOT IN ('cancelled', 'unavailable')
            AND o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL
            AND o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
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
    co.AvgItems,
    co.nb_item,
    co.ActualDeliveryTime,
    co.DeliveryDelay,
    s.AverageReviewScore,
    s.NumberOfReviews,
    s.NumberOfCommentTitles,
    s.NumberOfComments,
    c.DifferentCategories,
    co.AvgWeight,
    co.AvgVolume
FROM Recency r
JOIN Profile p ON r.customer_unique_id = p.customer_unique_id
JOIN Frequency f ON r.customer_unique_id = f.customer_unique_id
JOIN Monetary m ON r.customer_unique_id = m.customer_unique_id
LEFT JOIN Satisfaction s ON r.customer_unique_id = s.customer_unique_id
JOIN CustomerProducts c ON r.customer_unique_id = c.customer_unique_id
JOIN CustomerOrderDetail co ON r.customer_unique_id = co.customer_unique_id;



-- Select des moyens de paiement par client
WITH PaymentPreferences AS (
    SELECT 
        c.customer_unique_id,
        op.payment_type,
        COUNT(*) AS PaymentCount,
        SUM(op.payment_installments) AS TotalInstallments, 
        SUM(op.payment_value) AS TotalPaymentValue
    FROM 
        customers c
    JOIN 
        orders o ON c.customer_id = o.customer_id
    JOIN 
        order_pymts op ON o.order_id = op.order_id
    WHERE 
        o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY 
        c.customer_unique_id, op.payment_type
)
SELECT * FROM PaymentPreferences;
