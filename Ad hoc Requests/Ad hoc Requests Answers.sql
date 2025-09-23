-- Request 1
-- Monthly Circulation Drop Check 

with cte as 
(
select date_format(fact.formatted_months, "%Y-%m") as `month`, upper(city) as city_name,  
    sum(fact.Net_Circulation) as net_circulation
from fact_print_sales as fact
left join dim_city as dim
on dim.City_ID = fact.City_ID
group by date_format(fact.formatted_months, "%Y-%m"), city_name
order by city_name, `month`
),
cte_2 as 
(SELECT
    city_name,
    `month`,
    net_circulation,
    LAG(net_circulation) OVER (PARTITION BY city_name ORDER BY `month`) as previous_month_circulation,
    net_circulation - LAG(net_circulation) OVER (PARTITION BY city_name ORDER BY `month`) as mom_change
from cte
) select city_name, `month`, net_circulation, mom_change
from cte_2
where mom_change is not null
order by mom_change
limit 3;


-- Request 2
--  Yearly Revenue Concentration by Category


with cte as
(
select fact.ad_category as category_id,
	fact.year, fact.ad_revenue_in_inr, dim.standard_ad_category as category_name
from fact_ad_revenue  as fact
left join dim_ad_category as dim
on fact.ad_category = dim.ad_category_id
), cte_2 as
(
select `year`, 
           category_name, 
           sum(ad_revenue_in_inr) as category_revenue,
           sum(sum(ad_revenue_in_inr)) over(partition by `year`) as total_revenue_year
    from cte
    group by `year`, category_name
) select *,
	round((category_revenue / total_revenue_year) * 100 , 2) as pct_of_year_total
from cte_2
where (category_revenue / total_revenue_year * 100) > 50; -- There is no ad category which made more than 50% of the toal_yearly_ad_revenue



-- Request 3
-- 2024 Print Efficiency Leaderboard

with cte as
(
select 
		upper(dim.city) as city_name,
		sum((fact.copies_returned + fact.`Copies Sold`)) as copies_printed_2024,
        sum(fact.Net_Circulation) as net_circulation_2024
	from fact_print_sales as fact
left join dim_city as dim
on fact.City_ID = dim.City_ID
where year(formatted_months) = 2024
group by city_name
), cte_2 as
(select *,
		round(net_circulation_2024 / copies_printed_2024 , 4) as effeciency_ratio
    from cte
) select *, 
		row_number() over(order by effeciency_ratio desc) as effeciency_rank_2024
	from cte_2
    limit 5;
 
 
 
 -- Business Request – 4 
 -- Internet Readiness Growth (2021) 
 
 with cte as
(select upper(dim.city) as city_name,
		max(case when fct.`quarter` = '2021-Q1' then fct.internet_penetration end) as internet_rate_q1_2021,
        max(case when fct.`quarter` = '2021-Q4' then fct.internet_penetration end) as internet_rate_q4_2021,
        round(max(case when fct.`quarter` = '2021-Q4' then fct.internet_penetration end) -
        max(case when fct.`quarter` = '2021-Q1' then fct.internet_penetration end) , 2) as delta_internet_rate
from fact_city_readiness as fct
left join dim_city as dim
on  fct.city_id = dim.City_ID
group by city_name
)select * 
from cte 
order by delta_internet_rate desc
limit 1;
-- "KANPUR has the highest improvement with 2.5 delta internet rate, followed by MUMBAI at 2.43%..." 



-- Business Request – 5
-- Consistent Multi-Year Decline (2019→2024) 


with cte as
(select 
	upper(dim.city) as city_name,
    year(ft_sale.formatted_months) as `year`,
    sum(ft_sale.Net_Circulation) as yearly_net_circulation,
    sum(ft_ad.ad_revenue_in_inr) as yearly_ad_revenue
from 
	fact_print_sales as ft_sale
left join 
	dim_city as dim on ft_sale.City_ID = dim.City_ID
left join 
	fact_ad_revenue as ft_ad on ft_sale.edition_ID = ft_ad.edition_id
group by upper(dim.city), year(ft_sale.formatted_months) 
order by city_name
), cte_2 as
(
select *, 
	case 
		when yearly_net_circulation < lag(yearly_net_circulation) over(partition by city_name order by `year`) then 1
        else 0
        end as decline_print,
	case 
		when yearly_ad_revenue < lag(yearly_ad_revenue) over(partition by city_name order by `year`) then 1
        else 0
        end as declining_ad_revenue
from cte
), cte_3 as
(select city_name,
	`year`,
    yearly_net_circulation,
    yearly_ad_revenue,
	case
		when (sum(decline_print) over(partition by city_name)) =5 then "Yes" else "No"
        end as is_declining_print,
	case
		when (sum(declining_ad_revenue)over(partition by city_name)) =5 then "Yes" else "No"
        end as is_declining_ad_revenue,
	case 
		when (sum(decline_print) over(partition by city_name)) =5 and (sum(declining_ad_revenue)over(partition by city_name)) =5
		then "Yes" else "No"
		end as is_declining_both
from cte_2
) select *
from cte_3
where is_declining_both = "Yes"; -- There was NO CITY where both net_circulation and ad_revenue decreased every year from 2019 through 2024



-- Business Request – 6  
-- 2021 Readiness vs Pilot Engagement Outlier 

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
where fct_read.quarter like "2021%"
group by city_name
), cte_2 as
(select city_name,
        round((internet_rate + literacy_rate + smartphone_rate)/ 3, 2) as readiness_score_2021,
        round(((downloads_or_acess / users_reached) * 100), 2) as engagement_metric_2021,
        row_number() over(order by ((downloads_or_acess / users_reached) * 100) asc) as engagement_rank_asc,
        row_number() over (order by (internet_rate + literacy_rate + smartphone_rate)/ 3 desc) as readiness_rank_desc
from cte
order by engagement_rank_asc
), cte_3 as
(select *,
	case
    when abs((engagement_metric_2021 - (select avg(engagement_metric_2021) from cte_2)) / (select stddev(engagement_metric_2021) from cte_2)) > 2.5
    then "Yes"
    else "No"
    end as is_outlier
from cte_2 
) SELECT * FROM cte_3
where engagement_rank_asc <= 3
  ORDER BY readiness_rank_desc asc
	limit 1;

