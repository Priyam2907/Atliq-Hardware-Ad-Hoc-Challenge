select * from dim_customer;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT 
	distinct market 
FROM dim_customer 
where customer = "Atliq Exclusive" 
and region = "APAC";

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg

WITH unique_products AS (
	SELECT 
		fiscal_year,
		COUNT(DISTINCT product_code) AS unique_products
	FROM fact_sales_monthly
	WHERE fiscal_year IN (2020, 2021)
	GROUP BY fiscal_year
)

SELECT 
    MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END) AS unique_products_2020,
    MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) AS unique_products_2021,
    round((MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) - MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END)) * 100.0 / 
    MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END), 2) AS percentage_chg
FROM 
    unique_products;

-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
-- The final output contains 2 fields, segment product_count

select 
	segment, 
	count(distinct(product_code)) as product_count
from dim_product
group by segment 
order by product_count desc;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields, segment product_count_2020 product_count_2021 difference

WITH unique_products AS (
	SELECT 
		dim_product.segment, 
		fiscal_year,
		COUNT(DISTINCT product_code) AS unique_products
	FROM fact_sales_monthly join dim_product using (product_code) 
	WHERE fiscal_year IN (2020, 2021)
	GROUP BY dim_product.segment, fiscal_year
)

SELECT 
    segment,
    MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END) AS product_count_2020,
    MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) AS product_count_2021,
    (MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) - MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END)) AS difference
FROM 
    unique_products
group by segment;

-- 5. Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, product_code product manufacturing_cost

WITH manufacturing_costs AS (
    SELECT 
        dp.product_code,
        dp.product,
        fmc.manufacturing_cost,
        RANK() OVER (ORDER BY fmc.manufacturing_cost DESC) AS rank_highest,
        RANK() OVER (ORDER BY fmc.manufacturing_cost ASC) AS rank_lowest
    FROM dim_product dp
    JOIN fact_manufacturing_cost fmc 
    ON dp.product_code = fmc.product_code
)

SELECT 
    product_code,
    product,
    round(manufacturing_cost, 2) as manufacturing_cost
FROM manufacturing_costs
WHERE rank_highest = 1 OR rank_lowest = 1;

-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the 
-- fiscal year 2021 and in the Indian market. 
-- The final output contains these fields, customer_code customer average_discount_percentage

select 
	customer_code, 
	c.customer, 
	ROUND(pre_invoice_discount_pct*100,2) AS average_discount_percentage
	from fact_pre_invoice_deductions
join dim_customer c using(customer_code)
where pre_invoice_discount_pct >
(select avg(pre_invoice_discount_pct) as average_discount_percentage
from fact_pre_invoice_deductions
where fiscal_year = 2021)
and fiscal_year = 2021
and c.market = "India"
ORDER BY pre_invoice_discount_pct DESC
LIMIT 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
-- The final report contains these columns: Month Year Gross sales Amount

select 
       month(sm.date) as Month, 
       year(sm.date) as Year, 
       round(sum(sm.sold_quantity*gp.gross_price)) as Gross_Sales_Amount
from fact_sales_monthly sm
join fact_gross_price gp 
	on sm.product_code = gp.product_code
	and sm.fiscal_year = gp.fiscal_year
join dim_customer c
	on sm.customer_code = c.customer_code
where c.customer = "Atliq Exclusive"
group by sm.date 
order by Year and Month asc;


-- 8. In which quarter of 2020, got the maximum total_sold_quantity? 
-- The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity

SELECT 
	quarter(DATE_ADD(date, INTERVAL 4 MONTH)) AS quarter, sum(sold_quantity) AS
	total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY quarter ORDER BY total_sold_quantity DESC;


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields, channel gross_sales_mln percentage

with cte1 as 
	(select 
		   c.channel,
		   round(sum(sm.sold_quantity*gp.gross_price)) as gross_sales_Mln
	from fact_sales_monthly sm
	join fact_gross_price gp 
		on sm.product_code = gp.product_code
		and sm.fiscal_year = gp.fiscal_year
	join dim_customer c
		on sm.customer_code = c.customer_code
	where year(date) = 2021
	group by c.channel)

SELECT 
	channel, 
	gross_sales_mln, 
	ROUND(gross_sales_mln/(SELECT sum(gross_sales_mln) FROM cte1)*100) AS percentage
FROM cte1
ORDER BY percentage DESC;


-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields, division product_code product total_sold_quantity rank_order.

with cte1 AS 
	(SELECT 
		division, 
		sm.product_code, 
		product, 
		sum(sold_quantity) AS total_sold_quantity
	FROM fact_sales_monthly sm 
	JOIN dim_product p
		ON sm.product_code=p.product_code
	WHERE "2021"
	GROUP BY p.product_code, p.division, p.product
	ORDER BY p.division DESC, total_sold_quantity desc)
    
SELECT * FROM ( SELECT *, row_number() OVER(PARTITION BY division ORDER BY total_sold_quantity
DESC) AS rank_order FROM cte1)
RANKED
WHERE rank_order <= 3;