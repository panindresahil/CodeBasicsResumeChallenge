-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
-- business in the APAC region.

SELECT 
    market
FROM
    dim_customer
WHERE
    customer = 'Atliq Exclusive'
        AND region = 'APAC';


-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The
-- final output contains these fields,
-- unique_products_2020
-- unique_products_2021
-- percentage_chg
WITH unique_products_count AS (
SELECT 
    COUNT(DISTINCT CASE
            WHEN fiscal_year = 2020 THEN product_code
            ELSE NULL
        END) AS unique_products_count_2020,
    COUNT(DISTINCT CASE
            WHEN fiscal_year = 2021 THEN product_code
            ELSE NULL
        END) AS unique_products_count_2021
FROM
    fact_sales_monthly)

SELECT 
    unique_products_count_2020,
    unique_products_count_2021,
    ROUND(100.0 * ((unique_products_count_2021 - unique_products_count_2020) / unique_products_count_2021),
            2) AS percentage_chg
FROM
    unique_products_count;


-- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains 2 fields,
-- segment
-- product_count


SELECT 
    p.segment, COUNT(DISTINCT s.product_code) AS product_count
FROM
    dim_product p
        JOIN
    fact_sales_monthly s ON p.product_code = s.product_code
GROUP BY p.segment
ORDER BY product_count DESC;


-- 4. Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields,
-- segment
-- product_count_2020
-- product_count_2021
-- difference


WITH unique_products AS (
SELECT 
    p.segment,
    COUNT(DISTINCT CASE
            WHEN s.fiscal_year = 2020 THEN s.product_code
            ELSE NULL
        END) AS unique_product_2020,
    COUNT(DISTINCT CASE
            WHEN s.fiscal_year = 2021 THEN s.product_code
            ELSE NULL
        END) AS unique_product_2021
FROM
    dim_product p
        JOIN
    fact_sales_monthly s ON p.product_code = s.product_code
GROUP BY p.segment)

SELECT 
    segment,
    unique_product_2020,
    unique_product_2021,
    ROUND(100.0 * ((unique_product_2021 - unique_product_2020) / unique_product_2020),
            2) AS pct_difference
FROM
    unique_products
ORDER BY 4 DESC;


-- 5. Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields,
-- product_code
-- product
-- manufacturing_cost


SELECT 
    p.product_code, p.product, m.manufacturing_cost
FROM
    dim_product p
        JOIN
    fact_manufacturing_cost m ON m.product_code = p.product_code
WHERE
    m.manufacturing_cost = (SELECT 
            MAX(manufacturing_cost)
        FROM
            fact_manufacturing_cost) 
UNION ALL SELECT 
    p.product_code, p.product, m.manufacturing_cost
FROM
    dim_product p
        JOIN
    fact_manufacturing_cost m ON m.product_code = p.product_code
WHERE
    m.manufacturing_cost = (SELECT 
            MIN(manufacturing_cost)
        FROM
            fact_manufacturing_cost);


-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
-- customer_code
-- customer
-- average_discount_percentage

SELECT 
    c.customer_code,
    c.customer,
    ROUND((AVG(i.pre_invoice_discount_pct) * 100),
            2) AS average_discount_percentage
FROM
    fact_pre_invoice_deductions i
        JOIN
    dim_customer c ON c.customer_code = i.customer_code
WHERE
    i.fiscal_year = 2021
        AND c.market = 'India'
GROUP BY 1 , 2
ORDER BY 3 DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns:
-- Month
-- Year
-- Gross sales Amount


SELECT 
    s.date,
    s.fiscal_year,
    ROUND(SUM(gp.gross_price * s.sold_quantity), 2) AS gross_sales
FROM
    fact_gross_price gp
        JOIN
    fact_sales_monthly s ON s.product_code = gp.product_code
        AND s.fiscal_year = gp.fiscal_year
        JOIN
    dim_customer c ON c.customer_code = s.customer_code
WHERE
    c.customer = 'Atliq Exclusive'
GROUP BY 1 , 2
ORDER BY 1 , 2;



-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity,
-- Quarter
-- total_sold_quantity

SELECT 
    CASE
        WHEN MONTH(DATE) IN (9 , 10, 11) THEN 'Q1'
        WHEN MONTH(DATE) IN (12 , 1, 2) THEN 'Q2'
        WHEN MONTH(DATE) IN (3 , 4, 5) THEN 'Q3'
        ELSE 'Q4'
    END AS quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM
    fact_sales_monthly
WHERE
    fiscal_year = 2020
GROUP BY 1
ORDER BY 2 DESC;


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution? The final output contains these fields,
-- channel
-- gross_sales_mln
-- percentage

WITH gross_sales AS (
SELECT 
    c.channel,
    ROUND(SUM(gp.gross_price * s.sold_quantity) / 1000000,
            2) AS gross_sales_mln
FROM
    fact_gross_price gp
        JOIN
    fact_sales_monthly s ON gp.product_code = s.product_code
        AND gp.fiscal_year
        AND s.fiscal_year
        JOIN
    dim_customer c ON s.customer_code = c.customer_code
GROUP BY 1)

SELECT 
	channel, 
	gross_sales_mln,
	ROUND(100.0 * (gross_sales_mln / SUM(gross_sales_mln) OVER()), 2) AS percentage
FROM 
	gross_sales;



-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these
-- fields,
-- division
-- product_code

WITH products_sold AS (
SELECT 
    p.division,
    p.product_code,
    p.product,
    SUM(sold_quantity) AS total_sold_quantity
FROM
    fact_sales_monthly s
        JOIN
    dim_product p ON s.product_code = p.product_code
WHERE
    s.fiscal_year = 2021
GROUP BY 1, 2, 3
ORDER BY 1, 2 DESC),
products_sold_ranking AS (
SELECT *,
	DENSE_RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS rnk
FROM 
	products_sold)
    
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rnk AS rank_order
FROM
    products_sold_ranking
WHERE
    rnk <= 3



























