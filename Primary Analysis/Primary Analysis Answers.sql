-- 1. Print Circulation Trends

with cte as
(select 
	upper(city) as city_name,
    year(formatted_months) as `year`,
	sum(`Copies Sold`) as copies_sold,
	sum(`Copies Sold` + copies_returned) as  copies_printed,
    sum(Net_Circulation) as net_circulation
from fact_print_sales fact
left join dim_city as dim 
on dim.City_ID = fact.City_ID
group by city_name,  `year`
order by city_name, `year`
) ,cte_2 as
(select *,
	lag(copies_sold) over(partition by city_name order by `year`) as prev_copies_sold,
    lag(copies_printed) over(partition by city_name order by `year`) as prev_copies_printed,
    lag(net_circulation) over(partition by city_name order by `year`) as prev_net_circulation
from cte), cte_3 as
(select *,
	round(((copies_sold- prev_copies_sold) / prev_copies_sold) * 100,2) as YoY_copies_sold_change,
    round(((copies_printed - prev_copies_printed) / prev_copies_printed) * 100,2) as YoY_copies_printed_change,
    round(((net_circulation - prev_net_circulation) / prev_net_circulation) * 100,2) as YoY_net_circulation_change
from cte_2
) select
	city_name,
    `year`,
    YoY_copies_sold_change,
    YoY_copies_printed_change,
    YoY_net_circulation_change
from cte_3
where `year` != 2019;




-- 2. Top performing Cities


with cte as
(select upper(city) as City,
		Net_Circulation as Net_Circulation,
        `Copies Sold` as Copies_Sold,
        month(formatted_months) as `Months`
from fact_print_sales as fact
left join dim_city as dim
on fact.City_ID = dim.City_ID
where year(formatted_months) = '2024'
order by city asc, Months asc
) select *
from cte
where City in ('JAIPUR', 'MUMBAI', 'VARANASI'); -- This query will tell that if those cities are still profitable or not (I'll make a visualization through this)


select upper(city) as City,
		sum(Net_Circulation) as Net_Circulation,
        sum(`Copies Sold`) as Copies_Sold
from fact_print_sales as fact
left join dim_city as dim
on fact.City_ID = dim.City_ID
where year(formatted_months) = '2024'
group by city
order by Net_Circulation desc, Copies_Sold desc
limit 3; 
-- Top 3 cities make 42.38 % of total copies sold by all cities


-- 3. Print waste analysis


with cte as
(select 
	upper(city) as City,
	sum(`Copies Sold` + copies_returned) as  copies_printed,
    sum(Net_Circulation) as net_circulation
from fact_print_sales fact
left join dim_city as dim 
on dim.City_ID = fact.City_ID
group by City
order by City
) select City,
		(copies_printed - net_circulation) as waste
	from cte
    order by waste desc
    limit 3;  -- This is for cities who have the largest gap between copies printed and net circulation overall (from 2019 to 2024)
                          -- These top cities make 40.25 % of total waste caused in all cities



with cte as
(select 
	upper(city) as City,
	sum(`Copies Sold` + copies_returned) as  copies_printed,
    sum(Net_Circulation) as net_circulation,
    sum(`Copies Sold` + copies_returned) - sum(net_circulation) as waste, 
    year(formatted_months) as years
from fact_print_sales fact
left join dim_city as dim 
on dim.City_ID = fact.City_ID
group by City, years
order by City, years
), cte_2 as 
(select City,
		years,
		waste,
        lag(waste) over(partition by City order by years) as prev_waste
	from cte
)select 
	City,
    years,
    round(((waste - prev_waste) / prev_waste) * 100, 2) as YoY_change_in_gap
    from cte_2
    where City in ('JAIPUR', 'MUMBAI', 'VARANASI') and prev_waste is not null;  -- how the gap has changed over time
    
    
    
    
 -- 4. Ad Revenue Trends by Category    
 
 
 with cte as
 (select 
    standard_ad_category as ad_category,
    `year`,
    sum(ad_revenue_in_inr) as ad_revenue
 from fact_ad_revenue
 left join dim_ad_category
 on ad_category = ad_category_id
 group by standard_ad_category, `year`
 order by standard_ad_category, `year`
 ), cte_2 as 
 (select ad_category,
		sum(case when `year` = 2019 then ad_revenue end) as revenue_2019,
 		sum(case when `year` = 2024 then ad_revenue end) as revenue_2024,
        ROUND(
			100.0 * (SUM(CASE WHEN year = 2024 THEN ad_revenue END) -
           SUM(CASE WHEN year = 2019 THEN ad_revenue END))
			/ SUM(CASE WHEN year = 2019 THEN ad_revenue END), 2) AS pct_change
	from cte
 group by ad_category
 ) select
	ad_category,
    pct_change as growth
    from cte_2
    order by growth desc;
    
    
 
 
 -- 5. City-Level Ad Revenue Performance and corelation with print circulation
 
 
 select 
	upper(city) as City,
    sum(ad_revenue_in_inr) as ad_revenue,
    sum(Net_Circulation) as Net_Circulation,
   round((COUNT(*) * SUM(ad_revenue * Net_Circulation) - SUM(ad_revenue) * SUM(Net_Circulation)) /
    (SQRT(COUNT(*) * SUM(ad_revenue * ad_revenue) - (SUM(ad_revenue) * SUM(ad_revenue))) *
     SQRT(COUNT(*) * SUM(Net_Circulation * Net_Circulation) - (SUM(Net_Circulation) * SUM(Net_Circulation)))), 2) AS correlation_coefficient
 from fact_print_sales as ft_sale
 left join dim_city as dim on ft_sale.City_ID = dim.City_ID
 left join fact_ad_revenue  as ft_revenue on ft_sale.edition_ID = ft_revenue.edition_id
 group by city
 order by ad_revenue desc
 limit 5;  -- there is no co relation between both columns
							
                            
 
 
 -- 6.  Digital Readiness vs. Performance 
 
with cte as
(select upper(dim.city) as city_name,
        round(avg(fct_pilot.users_reached), 2) as users_reached,
        round(avg(fct_pilot.downloads_or_accesses),2) as downloads_or_acess,
        round(avg(fct_read.literacy_rate), 2) as literacy_rate, 
        round(avg(fct_read.smartphone_penetration), 2) as smartphone_rate,
        round(avg(fct_read.internet_penetration), 2) as internet_rate
from fact_city_readiness as fct_read
left join dim_city as dim on fct_read.city_id = dim.City_ID
left join fact_digital_pilot as fct_pilot  on fct_read.city_id = fct_pilot.city_id
group by city_name
) select city_name,
        round((internet_rate + literacy_rate + smartphone_rate)/ 3, 2) as digital_readiness,
        round(((downloads_or_acess / users_reached) * 100), 2) as pilot_engagement,
        row_number() over(order by ((downloads_or_acess / users_reached) * 100) asc) as engagement_rank_asc,
        row_number() over (order by (internet_rate + literacy_rate + smartphone_rate)/ 3 desc) as readiness_rank_desc
from cte
order by digital_readiness desc, pilot_engagement asc
limit 5;
 -- Kanpur had highest digital readiness ( how prepared a population (or city) is to adopt and benefit from digital technologies)
 -- but still it showed lowest engagement.
                                                       
										
                                        
                                        
 -- 7.  Ad Revenue vs. Circulation ROI 
 
 
 
 with cte as
 (select upper(city) as City,
		sum(ad_revenue_in_inr) as Ad_revenue,
        sum(Net_Circulation) as Net_circulation
 from fact_print_sales as ft_sales
 left join fact_ad_revenue as ft_revenue on ft_sales.edition_ID = ft_revenue.edition_id
 left join dim_city as dim on ft_sales.City_ID = dim.City_ID
 group by City
 ) select *,
	round((Ad_revenue / Net_circulation), 2) as Circulation_ROI
    from cte
    order by Circulation_ROI desc
    limit 3; -- which cities have highest circulation ROI
    
 
 
with cte as
 (select upper(city) as City,
		year(formatted_months) as years,
		sum(ad_revenue_in_inr) as Ad_revenue,
        sum(Net_Circulation) as Net_circulation
 from fact_print_sales as ft_sales
 left join fact_ad_revenue as ft_revenue on ft_sales.edition_ID = ft_revenue.edition_id
 left join dim_city as dim on ft_sales.City_ID = dim.City_ID
 group by City, years
 ) select *,
	round((Ad_revenue / Net_circulation), 2) as Circulation_ROI
    from cte
    order by City, years; -- is ratio improving or worsening over time? will check it through visulaiztion 
    
    
    
    
    
-- 8. Digital Relaunch City Prioritization 


with cte as
(select 
		upper(dim.city) as City,
        dim.City_ID,
        round(avg(fct_pilot.users_reached), 2) as users_reached,
        round(avg(fct_pilot.downloads_or_accesses),2) as downloads_or_acess,
        round(avg(fct_read.literacy_rate), 2) as literacy_rate, 
        round(avg(fct_read.smartphone_penetration), 2) as smartphone_rate,
        round(avg(fct_read.internet_penetration), 2) as internet_rate
       --  ,round(avg(ft_sales.`Copies Sold`),2) as copies_sold,
--         round(avg(ft_sales.copies_returned), 2) as copies_returned
from fact_print_sales as ft_sales
left join fact_digital_pilot as fct_pilot on ft_sales.City_ID = fct_pilot.city_id
left join dim_city as dim on ft_sales.City_ID = dim.City_ID 
left join fact_city_readiness as fct_read on ft_sales.City_ID = fct_read.city_id   
group by City, City_ID
),cte_2 as
(select
	City,
    City_ID,
    round((internet_rate + literacy_rate + smartphone_rate)/ 3, 2) as digital_readiness,
    round(((downloads_or_acess / users_reached) * 100), 2) as pilot_engagement
from cte), cte_3 as
(select 
	City,
    digital_readiness,
    pilot_engagement,
    sum(`Copies Sold`) as copies_sold,
    sum(copies_returned) as copies_returned,
    year(formatted_months) as years
from cte_2 
left join fact_print_sales as ft_sales on cte_2.City_ID = ft_sales.City_ID
group by City, digital_readiness, pilot_engagement, years
order by City, years
), cte_4 as
(select *,
	copies_sold + copies_returned as copies_printed
from cte_3
where years = '2019' or years = '2024'
), cte_5 as
(select
	City, 
    digital_readiness,
    pilot_engagement, 
    max(case when years = 2019 then copies_printed end) as copies_2019,
	max(case when years = 2024 then copies_printed end) as copies_2024
from cte_4
group by City, digital_readiness, pilot_engagement
) select 
	City, 
    digital_readiness,
    pilot_engagement, 
    case 
    when copies_2019 > copies_2024 then 'Yes' else 'No'
    end as print_decline
from cte_5
order by pilot_engagement desc, digital_readiness desc
limit 3;
