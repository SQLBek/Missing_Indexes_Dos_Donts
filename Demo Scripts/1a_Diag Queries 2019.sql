/*--------------------------------------------------------------------------------------------------
-- Tools - Missing Index Recommendations - w. Individual Queries - Aggregate
--
-- Written By: Andy Yun
-- Created On: 2021-10-19
-- 
-- Summary: Analyze Missing Index DMVs to assess what SQL thinks would help the most.
-- SQL Server 2019 + only
-- 
-- Source:
-- http://blogs.msdn.com/b/bartd/archive/2007/07/19/are-you-using-sql-s-missing-index-dmvs.aspx
-- Further modified by AYun
--------------------------------------------------------------------------------------------------*/
SELECT DISTINCT
	dm_db_missing_index_groups.index_group_handle,
	COUNT(dm_db_missing_index_group_stats_query.query_hash) 
		OVER(PARTITION BY dm_db_missing_index_groups.index_group_handle) AS num_queries,
	dm_db_missing_index_group_stats.unique_compiles, 

	dm_db_missing_index_group_stats.avg_total_user_cost 
	* (
		dm_db_missing_index_group_stats.avg_user_impact / 100.0
	) 
	* (
		dm_db_missing_index_group_stats.user_seeks + dm_db_missing_index_group_stats.user_scans
	) AS improvement_measure,           
	DB_NAME(dm_db_missing_index_details.database_id) AS database_name,
	REPLACE(REPLACE(dm_db_missing_index_details.statement, DB_NAME(dm_db_missing_index_details.database_id), ''), '[].', '') AS table_name, 
	dm_db_missing_index_details.equality_columns, 
	dm_db_missing_index_details.inequality_columns, 
	dm_db_missing_index_details.included_columns, 
	'|' AS '|',
	dm_db_missing_index_group_stats.user_seeks AS agg_user_seeks, 
	dm_db_missing_index_group_stats.user_scans AS agg_user_scans, 
	dm_db_missing_index_group_stats.last_user_seek AS agg_last_user_seek, 
	dm_db_missing_index_group_stats.last_user_scan AS agg_last_user_scan, 
	dm_db_missing_index_group_stats.avg_total_user_cost AS agg_avg_total_user_cost, 
	dm_db_missing_index_group_stats.avg_user_impact AS agg_avg_user_impact		-- Is a Percentage

FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats_query
	ON dm_db_missing_index_group_stats_query.group_handle = dm_db_missing_index_groups.index_group_handle
CROSS APPLY sys.dm_exec_sql_text(dm_db_missing_index_group_stats_query.last_sql_handle) AS dm_exec_sql_text

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
	improvement_measure DESC
GO







/*--------------------------------------------------------------------------------------------------
-- Tools - Missing Index Recommendations - w. Individual Queries - Detailed
--
-- Written By: Andy Yun
-- Created On: 2021-10-19
-- 
-- Summary: Analyze Missing Index DMVs to assess what SQL thinks would help the most.
-- SQL Server 2019 + only
-- 
-- Source:
-- http://blogs.msdn.com/b/bartd/archive/2007/07/19/are-you-using-sql-s-missing-index-dmvs.aspx
-- Further modified by AYun
--------------------------------------------------------------------------------------------------*/
SELECT
	dm_db_missing_index_groups.index_group_handle,
	COUNT(dm_db_missing_index_group_stats_query.query_hash) 
		OVER(PARTITION BY dm_db_missing_index_groups.index_group_handle) AS num_queries,
	dm_db_missing_index_group_stats.unique_compiles, 

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
	'=' AS '=',
    SUBSTRING
    (
            dm_exec_sql_text.text,
            dm_db_missing_index_group_stats_query.last_statement_start_offset / 2 + 1,
            (
            CASE dm_db_missing_index_group_stats_query.last_statement_start_offset
                WHEN -1 THEN DATALENGTH(dm_exec_sql_text.text)
                ELSE dm_db_missing_index_group_stats_query.last_statement_end_offset
            END - dm_db_missing_index_group_stats_query.last_statement_start_offset
            ) / 2 + 1
    ) AS sql_text,
	dm_db_missing_index_group_stats_query.query_hash,
	'|' AS '|',
	dm_db_missing_index_group_stats.user_seeks AS agg_user_seeks, 
	dm_db_missing_index_group_stats.user_scans AS agg_user_scans, 
	dm_db_missing_index_group_stats.last_user_seek AS agg_last_user_seek, 
	dm_db_missing_index_group_stats.last_user_scan AS agg_last_user_scan, 
	dm_db_missing_index_group_stats.avg_total_user_cost AS agg_avg_total_user_cost, 
	dm_db_missing_index_group_stats.avg_user_impact AS agg_avg_user_impact,		-- Is a Percentage
	'-' AS '-',
	dm_db_missing_index_group_stats_query.user_seeks AS query_user_seeks,
	dm_db_missing_index_group_stats_query.user_scans AS query_user_scans,
	dm_db_missing_index_group_stats_query.last_user_seek AS query_last_user_seek, 
	dm_db_missing_index_group_stats_query.last_user_scan AS query_last_user_scan, 
	dm_db_missing_index_group_stats_query.avg_total_user_cost AS query_avg_total_user_cost, 
	dm_db_missing_index_group_stats_query.avg_user_impact AS query_avg_user_impact

FROM sys.dm_db_missing_index_groups
INNER JOIN sys.dm_db_missing_index_group_stats 
	ON dm_db_missing_index_group_stats.group_handle = dm_db_missing_index_groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details
	ON dm_db_missing_index_groups.index_handle = dm_db_missing_index_details.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats_query
	ON dm_db_missing_index_group_stats_query.group_handle = dm_db_missing_index_groups.index_group_handle
CROSS APPLY sys.dm_exec_sql_text(dm_db_missing_index_group_stats_query.last_sql_handle) AS dm_exec_sql_text

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
	improvement_measure DESC,
	sql_text;
GO