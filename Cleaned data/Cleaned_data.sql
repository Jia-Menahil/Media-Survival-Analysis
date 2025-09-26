create database bharatherald;

select *
from fact_print_sales;


-- Checking for null values in fact_print_sales

select *
from fact_print_sales
where `formatted_months` = '' or `formatted_months` is null;

select *
from fact_print_sales
where `Net_Circulation` = '' or `Net_Circulation` is null;

select *
from fact_print_sales
where `City_ID` = '' or `City_ID`;


-- Standardizing the date

alter table fact_print_sales
add column formatted_months varchar(20);

update fact_print_sales
set formatted_months = 
    CONCAT('20', RIGHT(`Month`, 2), '-',
           CASE LEFT(`Month`, 3)
               WHEN 'Jan' THEN '01'
               WHEN 'Feb' THEN '02'
               WHEN 'Mar' THEN '03'
               WHEN 'Apr' THEN '04'
               WHEN 'May' THEN '05'
               WHEN 'Jun' THEN '06'
               WHEN 'Jul' THEN '07'
               WHEN 'Aug' THEN '08'
               WHEN 'Sep' THEN '09'
               WHEN 'Oct' THEN '10'
               WHEN 'Nov' THEN '11'
               WHEN 'Dec' THEN '12'
           END);

update fact_print_sales
set formatted_months = replace(`Month`, '/', '-')
WHERE formatted_months IS NULL 
  AND `Month` LIKE '%/%';

	
update fact_print_sales
set formatted_months = concat(formatted_months, "-01")
where formatted_months is not null;

alter table fact_print_sales
modify formatted_months date;


-- Checking for duplicate values

with cte as(
select *,
row_number() over(partition by City_ID, formatted_months, Net_Circulation) as rn
from fact_print_sales
) select *
from cte 
where rn > 1;



-- Request 2 : Yearly Revenue Concentration by Category 

-- Checking for null values
select *
from fact_ad_revenue
where ad_category is null or ad_category = '' or
edition_id is null or edition_id = '' or
quarter = '' or
ad_revenue is null or ad_revenue = '';

-- checking for duplicate values
with cte as
(
select *,
 row_number() over(partition by ad_category, quarter, ad_revenue) as rn
from fact_ad_revenue
) select * from cte
where rn > 1; 


-- Standardizing the quarter column to extract year (adding a new column 'year' extracted by quarter column)
SELECT 
    quarter,
    SUBSTRING(quarter, locate('20', `quarter`), 4) AS year
FROM fact_ad_revenue;

alter table fact_ad_revenue
add column year int;

update fact_ad_revenue
set `year` = SUBSTRING(quarter, locate('20', `quarter`), 4) ;


-- Adding a new column 'ad_revenue_in_inr'
alter table fact_ad_revenue
add column ad_revenue_in_inr double;

update fact_ad_revenue
set ad_revenue_in_inr = case
		when currency = 'EUR' then round((ad_revenue * 103.29), 0)
        when currency = 'USD' then round((ad_revenue * 88.17),0)
        when currency = 'INR' then ad_revenue
        else ad_revenue
        end;
        
        

 -- Business Request – 4 
 -- Internet Readiness Growth (2021) 
 
 select *
from fact_city_readiness;

-- Checking for null values 

select *
from fact_city_readiness
where city_id is null or city_id = ''; 

select *
from fact_city_readiness
where internet_penetration is null or internet_penetration = ''; 

select *
from fact_city_readiness
where `quarter` is null or `quarter` = ''; 

-- Checking for duplicate values

with cte as
(select *,
	row_number() over(partition by `quarter`, internet_penetration, city_id) as rn
from fact_city_readiness
)select * from cte 
where rn > 1;



-- Business Request – 6 : 2021 Readiness vs Pilot Engagement Outlier 

-- Checking for null values

select *
from fact_city_readiness
where literacy_rate is null or literacy_rate = '';


select *
from fact_city_readiness
where smartphone_penetration is null or smartphone_penetration = '';

select *
from fact_city_readiness
where internet_penetration is null or internet_penetration = '';


select *
from fact_digital_pilot
where users_reached is null or users_reached = '';  -- No null values were found


-- checking for duplicate values

with cte as
(select *,
	row_number() over(partition by city_id, quarter, literacy_rate, smartphone_penetration, internet_penetration) as rn
from fact_city_readiness
) select *
from cte 
where rn > 1  -- No duplicates found
