/*-----------------------------------------------------------------------------
-- 2_Key Ordering.sql
--
-- Written By: Andy Yun
-- Created On: 2021-10-19
-- 
-- Shout out to Brent Ozar and Bryan Rebok
-- https://dba.stackexchange.com/questions/208947/how-does-sql-server-determine-key-column-order-in-missing-index-requests
-----------------------------------------------------------------------------*/
USE CookbookDemo
GO


-------------
-- SETUP
-- Explain
-------------
IF EXISTS(SELECT 1 FROM sys.objects WHERE objects.name = 'KeysAscending')
	DROP TABLE demo.KeysAscending;
IF EXISTS(SELECT 1 FROM sys.objects WHERE objects.name = 'KeysReversed')
	DROP TABLE demo.KeysReversed;
GO
CREATE TABLE demo.KeysAscending (
	RecID INT IDENTITY(1, 1),
	AuthorFirstName	VARCHAR(250),
	CategoryName VARCHAR(250),
	DatePublished DATE,
	Protein_g DECIMAL(10, 2),
	RecipeName VARCHAR(250),
	Sugar_g DECIMAL(10, 2)
);

CREATE TABLE demo.KeysReversed (
	RecID INT IDENTITY(1, 1),
	Sugar_g DECIMAL(10, 2),
	RecipeName VARCHAR(250),
	Protein_g DECIMAL(10, 2),
	DatePublished DATE,
	CategoryName VARCHAR(250),
	AuthorFirstName	VARCHAR(250)
);
GO

CREATE CLUSTERED INDEX CK_demo_KeysAscending ON demo.KeysAscending (RecID);
CREATE CLUSTERED INDEX CK_demo_KeysReversed ON demo.KeysReversed (RecID);
GO

INSERT INTO demo.KeysAscending (
	AuthorFirstName,
	CategoryName,
	DatePublished,
	Protein_g,
	RecipeName,
	Sugar_g
)
SELECT 
	AuthorFirstName,
	CategoryName,
	CAST(DatePublished AS DATE) AS DatePublished,
	Protein_g,
	RecipeName,
	Sugar_g
FROM Recipes_Flat;
GO

INSERT INTO demo.KeysReversed (
	Sugar_g,
	RecipeName,
	Protein_g,
	DatePublished,
	CategoryName,
	AuthorFirstName
)
SELECT 
	Sugar_g,
	RecipeName,
	Protein_g,
	CAST(DatePublished AS DATE) AS DatePublished,
	CategoryName,	
	AuthorFirstName
FROM Recipes_Flat;
GO


---------------
-- SETUP END
---------------

/*
-----
-- Add a quick column cheat sheet here via sp_help
EXEC sp_help 'demo.KeysAscending';
	RecID
	AuthorFirstName
	CategoryName
	DatePublished
	Protein_g
	RecipeName
	Sugar_g

EXEC sp_help 'demo.KeysReversed';
	RecID
	Sugar_g
	RecipeName
	Protein_g
	DatePublished
	CategoryName
	AuthorFirstName
*/








-----
-- Example One
-- Equality Predicates
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 'Q1' AS Label,
	RecID, RecipeName
FROM demo.KeysAscending
WHERE AuthorFirstName = 'Amy'
	AND CategoryName = 'Pie'
	AND DatePublished = '2000-03-13';

SELECT 'Q2' AS Label,
	RecID, RecipeName
FROM demo.KeysReversed
WHERE AuthorFirstName = 'Amy'
	AND CategoryName = 'Pie'
	AND DatePublished = '2000-03-13';


-- Where's the Missing Index Rec?
-- Check Properties








-----
-- Example One - Round two
-- Equality Predicates
SELECT 'Q1' AS Label,
	RecID, RecipeName
FROM demo.KeysAscending
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND AuthorFirstName = 'Amy'
	AND CategoryName = 'Pie'
	AND DatePublished = '2000-03-13';

SELECT 'Q2' AS Label,
	RecID, RecipeName
FROM demo.KeysReversed
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND AuthorFirstName = 'Amy'
	AND CategoryName = 'Pie'
	AND DatePublished = '2000-03-13';








-----
-- Abbreviated Missing Index Rec diag query - 2019 version
-- Ctrl-M: Turn off Actual Execution Plan
SELECT
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	'|' AS '|',
	dm_db_missing_index_groups.index_group_handle,
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
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') IN (
		'[demo].[KeysAscending]', '[demo].[KeysReversed]'
	)
	AND SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) IN (
		'SELECT ''Q1', 'SELECT ''Q2'
	)
ORDER BY 
	sql_text;
GO








-----
-- OPTIONAL
-- Does order of the predicates make any difference?
SELECT 'Q3' AS Label,
	RecID, RecipeName
FROM demo.KeysReversed
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND CategoryName = 'Pie'
	AND DatePublished = '2000-03-13'
	AND AuthorFirstName = 'Amy';

SELECT 'Q4' AS Label,
	RecID, RecipeName
FROM demo.KeysReversed
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND DatePublished = '2000-03-13'
	AND AuthorFirstName = 'Amy'
	AND CategoryName = 'Pie';


-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	'|' AS '|',
	dm_db_missing_index_groups.index_group_handle,
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
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') IN (
		'[demo].[KeysAscending]', '[demo].[KeysReversed]'
	)
	AND SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) IN (
		'SELECT ''Q3', 'SELECT ''Q4'
	)
ORDER BY 
	sql_text;
GO








-----
-- Add a range predicate
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 'Q5' AS Label,
	RecID, RecipeName
FROM demo.KeysAscending
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND AuthorFirstName = 'Amy'
	AND CategoryName = 'Pie'
	AND DatePublished = '2000-03-13'
	AND Protein_g > 6.0;

SELECT 'Q6' AS Label,
	RecID, RecipeName
FROM demo.KeysReversed
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND AuthorFirstName = 'Amy'
	AND CategoryName = 'Pie'
	AND DatePublished = '2000-03-13'
	AND Protein_g > 6.0;

-- Check Missing Index Rec in execution plan
-- What's different here?








-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	'|' AS '|',
	dm_db_missing_index_groups.index_group_handle,
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
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') IN (
		'[demo].[KeysAscending]', '[demo].[KeysReversed]'
	)
	AND SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) IN (
		'SELECT ''Q5', 'SELECT ''Q6'
	)
ORDER BY 
	sql_text;
GO





-----
-- Add another INEQUALITY predicate
-- Ctrl-M: Turn on Actual Execution Plan
SELECT 'Q7' AS Label,
	RecID, RecipeName
FROM demo.KeysAscending
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND AuthorFirstName = 'Amy'
	AND CategoryName NOT IN ('Pie')
	AND DatePublished = '2000-03-13'
	AND Protein_g > 6.0


SELECT 'Q8' AS Label,
	RecID, RecipeName
FROM demo.KeysReversed
WHERE 1 > (SELECT 0)		-- force optimization to be non-trivial
	AND AuthorFirstName = 'Amy'
	AND CategoryName NOT IN ('Pie')
	AND DatePublished = '2000-03-13'
	AND Protein_g > 6.0

-- Check Missing Index Rec in execution plan
-- Show Plan XML now




-----
-- Abbreviated Missing Index Rec diag query
SELECT
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
    SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, (
		CASE dm_db_missing_index_group_stats_query.last_statement_start_offset WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
		ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset END - dm_db_missing_index_group_stats_query.last_statement_start_offset) / 2 + 1) AS sql_text,
	'|' AS '|',
	dm_db_missing_index_groups.index_group_handle,
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
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') IN (
		'[demo].[KeysAscending]', '[demo].[KeysReversed]'
	)
	AND SUBSTRING (dm_exec_sql_text.text, dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1, 10) IN (
		'SELECT ''Q7', 'SELECT ''Q8'
	)
ORDER BY 
	sql_text;
GO




/*
-- RESET Missing Index Recommendations
-- Dropping/re-adding clustered index will reset missing index recommendations
DROP INDEX demo.KeysAscending.CK_demo_KeysAscending
DROP INDEX demo.KeysReversed.CK_demo_KeysReversed
GO
CREATE CLUSTERED INDEX CK_demo_KeysAscending ON demo.KeysAscending (RecID);
CREATE CLUSTERED INDEX CK_demo_KeysReversed ON demo.KeysReversed (RecID);
GO
*/
