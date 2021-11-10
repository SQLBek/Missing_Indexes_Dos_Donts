/*-----------------------------------------------------------------------------
-- 3_Individual Queries.sql
--
-- Written By: Andy Yun
-- Created On: 2021-10-19
-- 
-- Summary: 
-- 
-----------------------------------------------------------------------------*/
USE CookbookDemo
GO




-----
-- Review Author Summary: Variation 1
-- 
-- Review predicates
-- Execute through diag query
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 'V1' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp1
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State NOT IN ('IL', 'WI')
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp1;


-----
-- Review Author Summary: Variation 2
SELECT 'V2' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp2
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State NOT IN (
		'IL', 'WI', 'NM', 'IA', 'MA', 'ME', 'OH', 'SC', 'WY', 'ID', 
		'MN', 'TN', 'HI', 'KS', 'AK', 'CT', 'PA', 'NE', 'AR', 'LA', 
		'VA', 'CO', 'MT', 'NY', 'WA', 'TX', 'NV', 'WV', 'NH'
	)
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp2;


-----
-- Review Author Summary: Variation 3
SELECT 'V3' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp3
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State = 'IL'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp3;
GO 3


-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_groups.index_group_handle,
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	'|' AS '|',
	dm_db_missing_index_group_stats.unique_compiles, 
	dm_db_missing_index_group_stats.user_seeks AS agg_user_seeks, 
	dm_db_missing_index_group_stats_query.user_seeks AS query_user_seeks,
	dm_db_missing_index_group_stats.avg_total_user_cost AS agg_avg_total_user_cost, 
	dm_db_missing_index_group_stats_query.avg_total_user_cost AS query_avg_total_user_cost, 
	dm_db_missing_index_group_stats.avg_user_impact AS agg_avg_user_impact,		-- Is a Percentage
	dm_db_missing_index_group_stats_query.avg_user_impact AS query_avg_user_impact,
	'|' AS '|',
	dm_db_missing_index_group_stats_query.query_hash, 
	dm_db_missing_index_group_stats_query.query_plan_hash
FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats_query
	ON dm_db_missing_index_group_stats_query.group_handle = dm_db_missing_index_groups.index_group_handle
CROSS APPLY sys.dm_exec_sql_text(dm_db_missing_index_group_stats_query.last_sql_handle) AS dm_exec_sql_text

WHERE /* Special predicate for this demo */
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') = '[dbo].[Reviews]'
	AND SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 11) LIKE 'SELECT ''V%'
ORDER BY 
	dm_db_missing_index_group_stats.avg_total_user_cost * dm_db_missing_index_group_stats.avg_user_impact * 
		(dm_db_missing_index_group_stats.user_seeks + dm_db_missing_index_group_stats.user_scans) DESC,
	sql_text;
GO

-- Review recommendation data
-- agg user seeks vs query user seeks
-- Review exec plan








-----
-- First here's the recommendation
/*
-- DROP INDEX Reviews.DemoIX_Reviews_Demo
CREATE NONCLUSTERED INDEX DemoIX_Reviews_Demo
ON dbo.Reviews (
	Approved, DateSubmitted
)
INCLUDE (
	AuthorID, DateModified, HelpfulScore
)
GO
*/




-----
-- What's columns are in the Reviews table?
-- Ctrl-M: Turn off Actual Execution Plan
EXEC sp_help 'dbo.Reviews';




-----
-- OR
EXEC sp_SQLSkills_helpindex 'dbo.Reviews';




-- What were our test predicates again?
/*
-- V1
WHERE Authors.State NOT IN ('IL', 'WI')
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1

-- V2
WHERE Authors.State NOT IN (
		'IL', 'WI', 'NM', 'IA', 'MA', 'ME', 'OH', 'SC', 'WY', 'ID', 
		'MN', 'TN', 'HI', 'KS', 'AK', 'CT', 'PA', 'NE', 'AR', 'LA', 
		'VA', 'CO', 'MT', 'NY', 'WA', 'TX', 'NV', 'WV', 'NH'
	)
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1

-- V3
WHERE Authors.State = 'IL'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
*/




-----
-- Cardinality?
SELECT Approved, 
	COUNT(1) AS NumberOfReviews
FROM dbo.Reviews
GROUP BY Approved;

SELECT 
	COUNT(1) AS TotalReview, 
	COUNT(DISTINCT DateSubmitted) DistinctDateSubmitted
FROM dbo.Reviews;


-- Which do you think is better?  Why?








-----
-- Let's create both then test!
CREATE NONCLUSTERED INDEX DemoIX_Reviews_Approved_DateSubmitted
ON dbo.Reviews (
	Approved, DateSubmitted
)
INCLUDE (
	AuthorID, DateModified, HelpfulScore
)
GO

CREATE NONCLUSTERED INDEX DemoIX_Reviews_DateSubmitted_Approved
ON dbo.Reviews (
	DateSubmitted, Approved
)
INCLUDE (
	AuthorID, DateModified, HelpfulScore
)
GO




-----
-- Re-run test code
--
-- Review Author Summary: Variation 1
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 'V1' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp1
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State NOT IN ('IL', 'WI')
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp1;


-----
-- Review Author Summary: Variation 2
SELECT 'V2' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp2
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State NOT IN (
		'IL', 'WI', 'NM', 'IA', 'MA', 'ME', 'OH', 'SC', 'WY', 'ID', 
		'MN', 'TN', 'HI', 'KS', 'AK', 'CT', 'PA', 'NE', 'AR', 'LA', 
		'VA', 'CO', 'MT', 'NY', 'WA', 'TX', 'NV', 'WV', 'NH'
	)
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp2;


-----
-- Review Author Summary: Variation 3
SELECT 'V3' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp3
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State = 'IL'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp3;
GO 

-----
-- STOP
-- Review ALL THREE execution plans








-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_groups.index_group_handle,
	dm_db_missing_index_group_stats_query.query_hash, 
	dm_db_missing_index_group_stats_query.query_plan_hash,
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') AS table_name, 
        
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	'|' AS '|',
	dm_db_missing_index_group_stats.unique_compiles, 
	dm_db_missing_index_group_stats.user_seeks AS agg_user_seeks, 
	dm_db_missing_index_group_stats_query.user_seeks AS query_user_seeks,
	dm_db_missing_index_group_stats.avg_total_user_cost AS agg_avg_total_user_cost, 
	dm_db_missing_index_group_stats_query.avg_total_user_cost AS query_avg_total_user_cost, 
	dm_db_missing_index_group_stats.avg_user_impact AS agg_avg_user_impact,		-- Is a Percentage
	dm_db_missing_index_group_stats_query.avg_user_impact AS query_avg_user_impact

FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats_query
	ON dm_db_missing_index_group_stats_query.group_handle = dm_db_missing_index_groups.index_group_handle
CROSS APPLY sys.dm_exec_sql_text(dm_db_missing_index_group_stats_query.last_sql_handle) AS dm_exec_sql_text

WHERE /* Special predicate for this demo */
	SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) IN (
		'SELECT ''V1', 'SELECT ''V2', 'SELECT ''V3'
	)
ORDER BY 
	sql_text;
GO


-- Notice something interesting about the new missing index recommendation?
-- Look at index_group_handle








-----
-- Review Author Summary: Variation 4 & 5
SELECT 'V4' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp5
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State = 'IL'
	AND Authors.FirstName LIKE 'A%'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp5;
GO

SELECT 'V5' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp6
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State LIKE 'I%'
	AND Authors.FirstName LIKE 'Amber%'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp6;
GO

-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_groups.index_group_handle,
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') AS table_name, 
        
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	dm_db_missing_index_group_stats_query.query_hash, 
	dm_db_missing_index_group_stats_query.query_plan_hash,
	'|' AS '|',
	dm_db_missing_index_group_stats.unique_compiles, 
	dm_db_missing_index_group_stats.user_seeks AS agg_user_seeks, 
	dm_db_missing_index_group_stats_query.user_seeks AS query_user_seeks,
	dm_db_missing_index_group_stats.avg_total_user_cost AS agg_avg_total_user_cost, 
	dm_db_missing_index_group_stats_query.avg_total_user_cost AS query_avg_total_user_cost, 
	dm_db_missing_index_group_stats.avg_user_impact AS agg_avg_user_impact,		-- Is a Percentage
	dm_db_missing_index_group_stats_query.avg_user_impact AS query_avg_user_impact

FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats_query
	ON dm_db_missing_index_group_stats_query.group_handle = dm_db_missing_index_groups.index_group_handle
CROSS APPLY sys.dm_exec_sql_text(dm_db_missing_index_group_stats_query.last_sql_handle) AS dm_exec_sql_text

WHERE /* Special predicate for this demo */
	SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) IN (
		'SELECT ''V1', 'SELECT ''V2', 'SELECT ''V3', 'SELECT ''V4', 'SELECT ''V5'
	)
ORDER BY 
	sql_text;
GO


-- Note V4 & V5
-- Note all of the Authors recommendations








-----
-- Who will use which index?
CREATE NONCLUSTERED INDEX DemoIX_Authors_State
ON dbo.Authors (
	State
)
INCLUDE (
	Alias, FirstName, LastName
)
GO

CREATE NONCLUSTERED INDEX DemoIX_Authors_State_FirstName
ON dbo.Authors (
	State, FirstName
)
INCLUDE (
	Alias, LastName
)
GO

CREATE NONCLUSTERED INDEX DemoIX_Authors_FirstName_State
ON dbo.Authors (
	FirstName, State
)
INCLUDE (
	Alias, LastName
)
GO




-----
-- Re-run test code
-- Variation 1-3 first
-- Remember, NO FirstName predicates here
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 'V1' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp1
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State NOT IN ('IL', 'WI')
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp1;


-----
-- Review Author Summary: Variation 2
SELECT 'V2' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp2
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State NOT IN (
		'IL', 'WI', 'NM', 'IA', 'MA', 'ME', 'OH', 'SC', 'WY', 'ID', 
		'MN', 'TN', 'HI', 'KS', 'AK', 'CT', 'PA', 'NE', 'AR', 'LA', 
		'VA', 'CO', 'MT', 'NY', 'WA', 'TX', 'NV', 'WV', 'NH'
	)
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp2;


-----
-- Review Author Summary: Variation 3
SELECT 'V3' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp3
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State = 'IL'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp3;
GO 

------
-- STOP
--
-- Look at Authors access method in each exec plan




-----
-- Re-run test code
-- Variation 4 & 5
SELECT 'V4' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp5
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State = 'IL'
	AND Authors.FirstName LIKE 'Amber%'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp5;
GO

SELECT 'V5' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp6
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State LIKE 'I%'
	AND Authors.FirstName LIKE 'Amber%'
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp6
GO

-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_groups.index_group_handle,
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') AS table_name, 
        
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	'|' AS '|',
	dm_db_missing_index_group_stats.avg_total_user_cost AS agg_avg_total_user_cost, 
	dm_db_missing_index_group_stats_query.avg_total_user_cost AS query_avg_total_user_cost, 
	dm_db_missing_index_group_stats.avg_user_impact AS agg_avg_user_impact,		-- Is a Percentage
	dm_db_missing_index_group_stats_query.avg_user_impact AS query_avg_user_impact,
	'|' AS '|',
	dm_db_missing_index_group_stats.unique_compiles, 
	dm_db_missing_index_group_stats.user_seeks AS agg_user_seeks, 
	dm_db_missing_index_group_stats_query.user_seeks AS query_user_seeks,
	'|' AS '|',
	dm_db_missing_index_group_stats_query.query_hash, 
	dm_db_missing_index_group_stats_query.query_plan_hash

FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats_query
	ON dm_db_missing_index_group_stats_query.group_handle = dm_db_missing_index_groups.index_group_handle
CROSS APPLY sys.dm_exec_sql_text(dm_db_missing_index_group_stats_query.last_sql_handle) AS dm_exec_sql_text

WHERE /* Special predicate for this demo */
	SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) IN (
		'SELECT ''V1', 'SELECT ''V2', 'SELECT ''V3', 'SELECT ''V4', 'SELECT ''V5'
	)
ORDER BY 
	sql_text;
GO


-- Reviews new recommendation?
-- Note COST vs IMPACT


-- How far down the rabbit hole do you continue to go?








----------------
-- OPTIONAL
-- Show behavior of unique_compiles vs user_seeks
-- Execute through diag query
SELECT 'V9' AS Label,
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State,
	COUNT(Reviews.ReviewID) AS NumberOfReviews,	AVG(Reviews.HelpfulScore) AS AvgHelpfulScore,
	MIN(Reviews.HelpfulScore) AS MinHelpfulScore, MAX(Reviews.HelpfulScore) AS MaxHelpfulScore
INTO #tmp1
FROM dbo.Reviews
INNER JOIN dbo.Authors
	ON Authors.AuthorID = Reviews.AuthorID
WHERE Authors.State NOT IN ('IL', 'WI')
	AND Reviews.DateSubmitted <> Reviews.DateModified
	AND Reviews.DateSubmitted > '2019-01-01'
	AND Reviews.Approved = 1
GROUP BY
	Authors.AuthorID, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.State
ORDER BY
	Authors.State, Authors.FirstName, Authors.LastName, Authors.Alias, Authors.AuthorID;

DROP TABLE #tmp1;

-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_group_stats.unique_compiles, 
	dm_db_missing_index_group_stats.user_seeks AS agg_user_seeks, 
	dm_db_missing_index_group_stats_query.user_seeks AS query_user_seeks,
	'|' AS '|',
	dm_db_missing_index_groups.index_group_handle,
	dm_db_missing_index_group_stats_query.query_hash, 
	dm_db_missing_index_group_stats_query.query_plan_hash,
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text
FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats_query
	ON dm_db_missing_index_group_stats_query.group_handle = dm_db_missing_index_groups.index_group_handle
CROSS APPLY sys.dm_exec_sql_text(dm_db_missing_index_group_stats_query.last_sql_handle) AS dm_exec_sql_text

WHERE /* Special predicate for this demo */
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') = '[dbo].[Reviews]'
	AND SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) = 'SELECT ''V9'
ORDER BY 
	dm_db_missing_index_group_stats.avg_total_user_cost * dm_db_missing_index_group_stats.avg_user_impact * 
		(dm_db_missing_index_group_stats.user_seeks + dm_db_missing_index_group_stats.user_scans) DESC,
	sql_text;
GO 3


-----
-- Repeat but highlight slight different text/spacing to invoke a fresh compile




