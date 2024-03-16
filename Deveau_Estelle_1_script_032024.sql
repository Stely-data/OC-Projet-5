-- En excluant les commandes annulées, quelles sont les commandes récentes de moins de 3 mois que les clients ont reçues avec au moins 3 jours de retard ?
WITH LatestOrderDate AS (
    SELECT MAX(order_purchase_timestamp) as MaxDate
    FROM orders
),
DateThreeMonthsAgo AS (
    SELECT DATE((SELECT MaxDate FROM LatestOrderDate), '-3 months') as DateLimit
),
RecentOrders AS (
    SELECT 
        o.order_id, 
        o.customer_id, 
        o.order_status, 
        o.order_estimated_delivery_date, 
        o.order_delivered_customer_date,
        o.order_status,
        julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) AS delay_days
    FROM orders o
    WHERE 
        o.order_approved_at >= (SELECT DateLimit FROM DateThreeMonthsAgo)
        AND o.order_status <> 'cancelled'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_delivered_customer_date > o.order_estimated_delivery_date
)
SELECT 
    ro.order_id, 
    ro.customer_id,
    ro.order_status,
    ro.order_estimated_delivery_date, 
    ro.order_delivered_customer_date, 
    ro.delay_days
FROM RecentOrders ro
WHERE ro.delay_days >= 3;



-- Qui sont les vendeurs ayant généré un chiffre d'affaires de plus de 100 000 Real sur des commandes livrées via Olist ?
SELECT 
    s.seller_id,
    SUM(oi.price) AS total_sales
FROM 
    sellers s
JOIN 
    order_items oi ON s.seller_id = oi.seller_id
JOIN 
    orders o ON oi.order_id = o.order_id
WHERE 
    o.order_status = 'delivered' 
GROUP BY 
    s.seller_id
HAVING 
    SUM(oi.price) > 100000 
;


-- Qui sont les nouveaux vendeurs (moins de 3 mois d'ancienneté) qui sont déjà très engagés avec la plateforme (ayant déjà vendu plus de 30 produits) ?
WITH LatestOrderDate AS (
    SELECT MAX(order_purchase_timestamp) as MaxDate
    FROM orders
),
NewSellers AS (
    SELECT 
        seller_id, 
        MIN(order_approved_at) AS first_sale_date
    FROM 
        orders o
    INNER JOIN 
        order_items oi ON o.order_id = oi.order_id
    GROUP BY 
        seller_id
    HAVING 
        julianday((SELECT MaxDate FROM LatestOrderDate)) - julianday(MIN(order_approved_at)) <= 90
),
TotalSales AS (
    SELECT 
        oi.seller_id, 
        COUNT(oi.product_id) AS total_sold
    FROM 
        order_items oi
    INNER JOIN 
        orders o ON oi.order_id = o.order_id
    WHERE 
        o.order_status = 'delivered'
    GROUP BY 
        oi.seller_id
    HAVING 
        COUNT(oi.product_id) > 30
)
SELECT 
    ns.seller_id,
    ns.first_sale_date,
    ts.total_sold
FROM 
    NewSellers ns
JOIN 
    TotalSales ts ON ns.seller_id = ts.seller_id;

   
   
-- Quels sont les 5 codes postaux, enregistrant plus de 30 commandes, avec le pire review score moyen sur les 12 derniers mois ?
WITH LatestOrderDate AS (
    SELECT MAX(order_purchase_timestamp) AS MaxDate
    FROM orders
),
RelevantOrders AS (
    SELECT
        c.customer_zip_code_prefix,
        r.review_score
    FROM
        customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    INNER JOIN 
        order_reviews r ON o.order_id = r.order_id,
        LatestOrderDate
    WHERE
        o.order_approved_at BETWEEN date((SELECT MaxDate FROM LatestOrderDate), '-12 months') AND (SELECT MaxDate FROM LatestOrderDate)
        AND o.order_status <> 'cancelled'
),
AggregatedData AS (
    SELECT
        customer_zip_code_prefix,
        AVG(review_score) as average_review_score,
        COUNT(*) as total_orders
    FROM
        RelevantOrders
    GROUP BY
        customer_zip_code_prefix
    HAVING
        COUNT(*) > 30
)
SELECT
    customer_zip_code_prefix,
    average_review_score,
    total_orders
FROM
    AggregatedData
ORDER BY
    average_review_score ASC,
    total_orders DESC
LIMIT 5;
