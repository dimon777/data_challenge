/*
Query 1
Select the standard deviation and average of the assets, revenues and market
cap for each sector group.
*/
SELECT sector_group,
       stddev(market_cap) stddev_mc,
       stddev(assets) stddev_assets,
       stddev(revenues)  stddev_revenues,
       avg(market_cap) avg_mc,
       avg(assets) avg_assets,
       avg(revenues) avg_revenues
FROM companies_latest
 GROUP BY sector_group;

/*
Query 2
Using the query FROM above (1), compute the standardized values for each
company, using the following standardization function:
STANDARDIZED(x) = ( x - MEAN(x) ) / STDEV(x)
*/
SELECT c.company_id, c.company_name, g.sector_group,
(c.market_cap-avg_mc)/g.stddev_mc mkcp_standardized,
(c.assets - avg_assets)/g.stddev_assets assets_standardized,
(c.revenues - avg_revenues)/g.stddev_revenues revenue_standardized
FROM companies_latest c
JOIN (SELECT sector_group,
       stddev(market_cap) stddev_mc,
       stddev(assets) stddev_assets,
       stddev(revenues)  stddev_revenues,
       avg(market_cap) avg_mc,
       avg(assets) avg_assets,
       avg(revenues) avg_revenues
        FROM companies_latest
       GROUP BY sector_group) g
ON c.sector_group = g.sector_group;

/*
Query 3
Using the query FROM above (2), add a new column to the select statement
called combined_metric. The formula for the combined_metric will be:
0.4*mkcp_standardized + 0.3*assets_standardized + 0.3*revenue_standardized
*/
SELECT c.company_id, c.company_name, g.sector_group,
(c.market_cap - avg_mc)/g.stddev_mc mkcp_standardized,
(c.assets - avg_assets)/g.stddev_assets assets_standardized,
(c.revenues - avg_revenues)/g.stddev_revenues revenue_standardized,
0.4*(c.market_cap - avg_mc)/g.stddev_mc + 0.3*(c.assets - avg_assets)/g.stddev_assets + 0.3*(c.revenues - avg_revenues)/g.stddev_revenues combined_metric
FROM companies_latest c
JOIN (SELECT sector_group,
       stddev(market_cap) stddev_mc,
       stddev(assets) stddev_assets,
       stddev(revenues)  stddev_revenues,
       avg(market_cap) avg_mc,
       avg(assets) avg_assets,
       avg(revenues) avg_revenues
        FROM companies_latest
       GROUP BY sector_group) g
ON c.sector_group = g.sector_group;

/*
Query 4
Finally we want to assign a size group (S, M, L, XL) to all companies based on
their combined metric we just calculated in step (3). To pick the category, use
the following logic:
- Combined metric less than the 1st quartile (column q1 in the quartiles table)
- Combined metric less than the 2nd quartile (column q2 in the quartiles table)
- Combined metric less than the 3rd quartile (column q3 in the quartiles table)
- Combined metric larger than the 3rd quartile
*/
SELECT x.*,
       CASE
         WHEN x.combined_metric < q.q1 THEN 'S'
         WHEN x.combined_metric < q.q2 THEN 'M'
         WHEN x.combined_metric < q.q3 THEN 'L'
         WHEN x.combined_metric >= q.q3 THEN 'XL'
       END as size_group
FROM(
SELECT c.company_id, c.company_name, g.sector_group,
(c.market_cap - avg_mc)/g.stddev_mc mkcp_standardized,
(c.assets - avg_assets)/g.stddev_assets assets_standardized,
(c.revenues - avg_revenues)/g.stddev_revenues revenue_standardized,
0.4*(c.market_cap - avg_mc)/g.stddev_mc + 0.3*(c.assets - avg_assets)/g.stddev_assets + 0.3*(c.revenues - avg_revenues)/g.stddev_revenues combined_metric
FROM companies_latest c
JOIN (SELECT sector_group,
       stddev(market_cap) stddev_mc,
       stddev(assets) stddev_assets,
       stddev(revenues)  stddev_revenues,
       avg(market_cap) avg_mc,
       avg(assets) avg_assets,
       avg(revenues) avg_revenues
        FROM companies_latest
       GROUP BY sector_group) g
ON c.sector_group = g.sector_group) x
JOIN quartiles q
ON x.sector_group = q.sector_group;
