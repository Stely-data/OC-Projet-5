WITH CustomerProductCounts AS (
    SELECT 
        c.customer_unique_id,
        COALESCE(t.product_category_name_english, 'Miscellaneous') AS product_category_name_english,
        COUNT(*) AS CategoryCount,
        SUM(oi.price) AS TotalSpentPerCategory
    FROM 
        customers c
    JOIN 
        orders o ON c.customer_id = o.customer_id
    JOIN 
        order_items oi ON oi.order_id = o.order_id
    JOIN 
        products p ON p.product_id = oi.product_id
    LEFT JOIN 
        translation t ON p.product_category_name = t.product_category_name
    WHERE 
        o.order_status NOT IN ('cancelled', 'unavailable')
    GROUP BY 
        c.customer_unique_id,
        COALESCE(t.product_category_name_english, 'Miscellaneous')
)
SELECT * FROM CustomerProductCounts;



WITH PaymentPreferences AS (
    SELECT 
        c.customer_unique_id,
        op.payment_type,
        COUNT(*) AS PaymentCount,
        SUM(op.payment_value) AS TotalPaymentValue
    FROM 
        customers c
    JOIN 
        orders o ON c.customer_id = o.customer_id
    JOIN 
        order_pymts op ON o.order_id = op.order_id
    GROUP BY 
        c.customer_unique_id, op.payment_type
)
SELECT * FROM PaymentPreferences;

