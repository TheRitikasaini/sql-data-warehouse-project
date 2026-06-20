-- 7. Change over time
-- Analyze sales performance over time
SELECT 
YEAR(order_date) as order_YEAR,
MONTH(order_date) as order_month,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date)

SELECT 
DATETRUNC(MONTH, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date) 
ORDER BY DATETRUNC(MONTH, order_date)

SELECT 
FORMAT(order_date, 'yyyy-MMM') AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM') 
ORDER BY FORMAT(order_date, 'yyyy-MMM')


-- 8. Cumulative analysis
/* Calculate the total sales per month 
and the running total of sales over time */
select
order_date,
total_sales,
sum(total_sales) over (order by order_date) as running_total_sales,
avg(avg_price) over (order by order_date) as moving_average_price
from (
	select 
	datetrunc(year, order_date) as order_date,
	sum(sales_amount) as total_sales,
	avg(price) as avg_price
	from gold.fact_sales
	where order_date is not null
	group by datetrunc(year, order_date)
	) t


-- 9. Performance analysis
/* Analyze the yearly performance of products by comparing the sales
to both the average sales performance of the product and the previous year's sales */
with yearly_product_sales as (
select
year(f.order_date) as order_year,
p.product_name,
sum(f.sales_amount) as current_sales
from gold.fact_sales f
left join gold.dim_products p
on f.product_key = p.product_key
where f.order_date is not null
group by year(f.order_date), p.product_name
)
select 
order_year,
product_name,
current_sales,
avg(current_sales) over (partition by product_name) avg_sales,
current_sales - avg(current_sales) over (partition by product_name) as diff_avg,
case when current_sales - avg(current_sales) over (partition by product_name) > 0 then 'Above avg'
	 when current_sales - avg(current_sales) over (partition by product_name) < 0 then 'Below avg'
	 else 'Avg'
end avg_change,
-- Year-over-year Analysis
lag(current_sales) over (partition by product_name order by order_year) py_sales,
current_sales - lag(current_sales) over (partition by product_name order by order_year) diff_py,
case when current_sales - lag(current_sales) over (partition by product_name order by order_year)  > 0 then 'Increase'
	 when current_sales - lag(current_sales) over (partition by product_name order by order_year)  < 0 then 'Decrease'
	 else 'No change'
end py_change
from yearly_product_sales
order by product_name, order_year


-- 10. Part to whole (proportional analysis)
-- which categories contribute the most to overall sales?

with category_sales as (
select
category,
sum(sales_amount) total_sales
from gold.fact_sales f
left join gold.dim_products p
on p.product_key = f.product_key
group by category )

select
category,
total_sales,
sum(total_sales) over () overall_sales,
concat(round((cast (total_sales as float)/sum(total_sales) over ()) * 100, 2), '%') as percentage_of_total
from category_sales
order by total_sales DESC


-- 11. Data segmentaion
/* Segment products into cost ranges and 
count how many products fall into each segment */
with product_segment as (
select
product_key,
product_name,
cost,
case when cost < 100 then 'Below 100'
	 when cost between 100 and 500 then '100 - 500'
	 when cost between 500 and 1000 then '500 - 1000'
	 else 'Above 1000'
end cost_range
from gold.dim_products )

select
cost_range,
count(product_key) as total_products
from product_segment
group by cost_range
order by total_products desc


/* Group customers into three segments based on their spending behavior:
	- VIP: Customers with at least 12 months of history and spending more than $5000
	- Regular: Customers with at least 12 months of history but spending $5000 or less.
	- New: Customers with less than 12 months of history
	and find the total number of customers by each group */
with customer_spending as (
select
c.customer_key,
sum(f.sales_amount) as total_spending,
min(order_date) as first_order,
max(order_date) as last_order,
datediff (month, min(order_date), max(order_date)) as lifespan
from gold.fact_sales f
left join gold.dim_customers c
on f.customer_key = c.customer_key
group by c.customer_key )

select 
segment,
count(customer_key) as total_customers
from (
	select
	customer_key,
	case when lifespan >= 12 and total_spending > 5000 then 'VIP'
		 when lifespan >= 12 and total_spending <= 5000 then 'Regular'
		 else 'New'
	end as segment
	from customer_spending) t
group by segment
order by total_customers desc


