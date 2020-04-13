
/* Query 1
Create a new table that contains only the latest record
(hint: use pricing_date) for each company
*/

-- slow case:
CREATE TABLE companies_latest as SELECT * FROM companies a
 WHERE pricing_date = (SELECT max(pricing_date) 
	                 FROM companies b where b.company_id = a.company_id);

-- faster case:
CREATE TABLE companies_latest AS
SELECT c.* FROM
(SELECT company_id, max(pricing_date) last_pricing_date
   FROM companies GROUP BY company_id) g
JOIN
   companies c
ON c.company_id = g.company_id AND c.pricing_date = g.last_pricing_date;

/* Query 2
Select the top 10 companies ranked by their market cap
for each sector group
*/
SELECT * FROM (
SELECT
   t.company_name,
   t.sector_group,
   t.market_cap,
   @rank := CASE WHEN @sector != sector_group THEN 1 ELSE @rank+1 END AS rn,
   @sector := sector_group sector_g
FROM
   (SELECT @rank := 1) r,
   (SELECT @sector := '') s,
   (SELECT * FROM companies_latest ORDER BY sector_group, market_cap DESC) t
) z
WHERE rn <= 10;
