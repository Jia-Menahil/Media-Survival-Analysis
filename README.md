# Media-Survival-Analysis
This project is done as a challenge by code basics resume challenges. It contains following files:
- Data Cleaning File:
- Answers of Ad hoc requests:https://github.com/Jia-Menahil/Media-Survival-Analysis/blob/main/Ad%20hoc%20Requests%20(main).sql
- Primary Analysis: https://github.com/Jia-Menahil/Media-Survival-Analysis/blob/main/Primary_analysis.sql
- Power BI Dashboard

# Business Requests
## Business Request – 1: Monthly Circulation Drop Check

``` sql
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
```

<img width="347" height="107" alt="Request 1" src="https://github.com/user-attachments/assets/92f6ef1d-9560-40e4-bd24-f0f3e9b53664" />

## Business Request – 2: Yearly Revenue Concentration by Category 

``` sql
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
```

<img width="565" height="130" alt="Request 2" src="https://github.com/user-attachments/assets/b5874e6a-86a6-4bd4-b566-2dbdb8587a93" />

## Business Request – 3: 2024 Print Efficiency Leaderboard

``` sql
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
```

<img width="564" height="144" alt="Request 3" src="https://github.com/user-attachments/assets/a4cc5a30-e9cd-459b-b45e-62bf59ee6f15" />

## Business Request – 4 : Internet Readiness Growth (2021)

``` sql
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
```

<img width="501" height="60" alt="Request 4" src="https://github.com/user-attachments/assets/03bb857c-27f4-4d71-8a54-78db4b54182e" />

## Business Request – 5: Consistent Multi-Year Decline (2019→2024) 

``` sql
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
where is_declining_both = "Yes";
-- There was NO CITY where both net_circulation and ad_revenue decreased every year from 2019 through 2024
```

<img width="713" height="56" alt="Request 5" src="https://github.com/user-attachments/assets/e6497780-445c-46d6-aa7b-4ddc6d41d81c" />

## Business Request – 6 : 2021 Readiness vs Pilot Engagement Outlier 

``` sql
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
```

<img width="683" height="69" alt="Request 6" src="https://github.com/user-attachments/assets/a48b99d1-3ce8-43f3-b5c2-7ceaefcd5a03" />


## Visualization Through Power BI

The power bi report has 3 pages in total. 

- Print Business Health 

<img width="929" height="519" alt="Codebasics_dashboard_P1" src="https://github.com/user-attachments/assets/c47c4bf8-1d2b-4418-aa06-9b77e2f8f40f" />

- Revenue Analysis

<img width="927" height="519" alt="image" src="https://github.com/user-attachments/assets/fcd08b60-bc41-4db1-9056-8aad06f54da4" />

- Digital Performance 2021

<img width="926" height="519" alt="Codebasics_dashboard_P3" src="https://github.com/user-attachments/assets/fe01bb2a-ffed-42b0-b0c2-f2b499b24f39" />


# Primary Analysis
 ## 1. Print Circulation Trend
 What is the trend in copies printed, copies sold, and net circulation across all 
cities from 2019 to 2024? How has this changed year-over-year?
<img width="995" height="554" alt="Primarry Q 1" src="https://github.com/user-attachments/assets/89f791f1-6ca1-4c1e-b4bf-ce5344852453" />

## 2. To Performing Cities 
Which cities contributed the highest to net circulation and copies sold in 2024? 
Are these cities still profitable to operate in?

<img width="302" height="96" alt="Primarry Q 2 second part" src="https://github.com/user-attachments/assets/96f545be-303c-45f4-8784-1aede79b75c4" />

<img width="995" height="548" alt="Primarry Q 2" src="https://github.com/user-attachments/assets/4e02425e-bd92-412a-b77a-d7fd112f8d9a" />

## 3. Print Waste Analysis 
Which cities have the largest gap between copies printed and net circulation, and 
how has that gap changed over time?

<img width="218" height="104" alt="Primarry Q 3" src="https://github.com/user-attachments/assets/63fa2e89-c500-43f0-8fc9-a21a4fb8c7b8" />

<img width="996" height="554" alt="Primarry Q 3 second part" src="https://github.com/user-attachments/assets/1f2be098-3307-4090-824f-fe93519d90a2" />

## 4. Ad Revenue Trends by Category 
How has ad revenue evolved across different ad categories between 2019 and 
2024? Which categories have remained strong, and which have declined?

<img width="192" height="122" alt="Primarry Q 4" src="https://github.com/user-attachments/assets/245e325f-24c0-41e2-b085-ec312dce6d53" />

<img width="464" height="316" alt="Primarry Q 4 second part" src="https://github.com/user-attachments/assets/c16e0f94-62fc-4f6b-b591-e396dc176c35" />

## 5. City-Level Ad Revenue Performance 
Which cities generated the most ad revenue, and how does that correlate with 
their print circulation?

<img width="426" height="296" alt="Primarry Q 5" src="https://github.com/user-attachments/assets/ce2f276c-6aae-4f25-90c2-06a720169ab7" />

## 6. Digital Readiness vs. Performance 
Which cities show high digital readiness (based on smartphone, internet, and 
literacy rates) but had low digital pilot engagement? 

<img width="598" height="150" alt="Primarry Q 6" src="https://github.com/user-attachments/assets/51e6beee-e6d2-4d85-9942-14d791b79363" />

## 7. Ad Revenue vs. Circulation ROI 
Which cities had the highest ad revenue per net circulated copy? Is this ratio 
improving or worsening over time? 

<img width="404" height="97" alt="Primarry Q 7" src="https://github.com/user-attachments/assets/00744fc4-1068-473e-849b-ba478a538b6e" />

<img width="994" height="545" alt="Primarry Q 7 Second" src="https://github.com/user-attachments/assets/0d4b39d6-ebc0-4fe2-baeb-330657271981" />

## 8. Digital Relaunch City Prioritization 
Based on digital readiness, pilot engagement, and print decline, which 3 cities should be 
prioritized for Phase 1 of the digital relaunch? 

<img width="479" height="106" alt="Primarry Q 8" src="https://github.com/user-attachments/assets/0afb8864-bb63-4189-ab17-03b40f28deba" />


## Connect with me 
🙋 Author: Jia Menahil Rasheed

LinkedIn: https://www.linkedin.com/in/jia-rasheed-b030962ba/

Email: jiarasheed7@gmail.com

#### ⭐ If you like this project, please give it a star!
