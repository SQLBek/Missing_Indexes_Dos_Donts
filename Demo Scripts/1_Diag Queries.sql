USE CookbookDemo
GO

/*--------------------------------------------------------------------------------------------------
-- Tools - Missing Index Recommendations - Summary
--
-- Written By: Andy Yun
-- Created On: 2010-01-01
-- 
-- Summary: Analyze Missing Index DMVs to assess what SQL thinks would help the most.
-- 
-- Source:
-- http://blogs.msdn.com/b/bartd/archive/2007/07/19/are-you-using-sql-s-missing-index-dmvs.aspx
-- Further modified by AYun
--------------------------------------------------------------------------------------------------*/
SELECT
	dm_db_missing_index_groups.index_group_handle,
	dm_db_missing_index_group_stats.avg_total_user_cost 
	* (
		dm_db_missing_index_group_stats.avg_user_impact / 100.0
	) 
	* (
		dm_db_missing_index_group_stats.user_seeks + dm_db_missing_index_group_stats.user_scans
	) 
	AS improvement_measure,           
	DB_NAME(dm_db_missing_index_details.database_id) AS database_name,
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') AS table_name, 
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	dm_db_missing_index_group_stats.unique_compiles, 
	dm_db_missing_index_group_stats.user_seeks, 
	dm_db_missing_index_group_stats.user_scans, 
	dm_db_missing_index_group_stats.last_user_seek, 
	dm_db_missing_index_group_stats.last_user_scan, 
	dm_db_missing_index_group_stats.avg_total_user_cost, 
	dm_db_missing_index_group_stats.avg_user_impact		-- Is a Percentage
FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
/* Limit where calculated impact is > 10 */
WHERE 
	dm_db_missing_index_group_stats.avg_total_user_cost 
		* (
			dm_db_missing_index_group_stats.avg_user_impact / 100.0
		) 
		* (
			dm_db_missing_index_group_stats.user_seeks + dm_db_missing_index_group_stats.user_scans
		) > 10

/* Only for DEMO */
-- AND dm_db_missing_index_details.database_id = DB_ID(N'DatabaseName')
-- AND REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') = '[dbo].[TableName]'

ORDER BY 
	improvement_measure DESC;
GO








/*--------------------------------------------------------------------------------------------------
-- Tools - Find Missing Indexes in the Plan Cache
--
-- Written By: Jonathan Kehayias (SQLskills)
-- Published On: 2009-07-27
-- 
-- Summary: Analyze Execution Plans in cache to find plans with a missing index recommendation
-- 
-- Source:
-- https://www.sqlskills.com/blogs/jonathan/digging-into-the-sql-plan-cache-finding-missing-indexes/
--------------------------------------------------------------------------------------------------*/
WITH XMLNAMESPACES
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
 
SELECT query_plan,
       n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text,
       n.value('(//MissingIndexGroup/@Impact)[1]', 'FLOAT') AS impact,
       DB_ID(REPLACE(REPLACE(n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)'),'[',''),']','')) AS database_id,
       OBJECT_ID(n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)') + '.' +
           n.value('(//MissingIndex/@Schema)[1]', 'VARCHAR(128)') + '.' +
           n.value('(//MissingIndex/@Table)[1]', 'VARCHAR(128)')) AS OBJECT_ID,
       n.value('(//MissingIndex/@Database)[1]', 'VARCHAR(128)') + '.' +
           n.value('(//MissingIndex/@Schema)[1]', 'VARCHAR(128)') + '.' +
           n.value('(//MissingIndex/@Table)[1]', 'VARCHAR(128)')
       AS statement,
       (   SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', '
           FROM n.nodes('//ColumnGroup') AS t(cg)
           CROSS APPLY cg.nodes('Column') AS r(c)
           WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'EQUALITY'
           FOR  XML PATH('')
       ) AS equality_columns,
        (  SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', '
           FROM n.nodes('//ColumnGroup') AS t(cg)
           CROSS APPLY cg.nodes('Column') AS r(c)
           WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'INEQUALITY'
           FOR  XML PATH('')
       ) AS inequality_columns,
       (   SELECT DISTINCT c.value('(@Name)[1]', 'VARCHAR(128)') + ', '
           FROM n.nodes('//ColumnGroup') AS t(cg)
           CROSS APPLY cg.nodes('Column') AS r(c)
           WHERE cg.value('(@Usage)[1]', 'VARCHAR(128)') = 'INCLUDE'
           FOR  XML PATH('')
       ) AS include_columns
INTO #MissingIndexInfo
FROM
(
   SELECT query_plan
   FROM (
           SELECT DISTINCT plan_handle
           FROM sys.dm_exec_query_stats WITH(NOLOCK)
         ) AS qs
       OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp
   WHERE tp.query_plan.exist('//MissingIndex')=1
) AS tab (query_plan)
CROSS APPLY query_plan.nodes('//StmtSimple') AS q(n)
WHERE n.exist('QueryPlan/MissingIndexes') = 1;
 
-- Trim trailing comma from lists
UPDATE #MissingIndexInfo
SET equality_columns = LEFT(equality_columns,LEN(equality_columns)-1),
   inequality_columns = LEFT(inequality_columns,LEN(inequality_columns)-1),
   include_columns = LEFT(include_columns,LEN(include_columns)-1);
 
SELECT *
FROM #MissingIndexInfo;
 
DROP TABLE #MissingIndexInfo;
GO