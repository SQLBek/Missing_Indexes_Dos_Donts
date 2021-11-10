/*-------------------------------------------------------------------
-- 0 - Reset
-- 
-- Summary: 
--
-- Written By: Andy Yun
-------------------------------------------------------------------*/

/***************************************
*** RUN WORKLOAD AFTER THIS          ***
***
*** Toss this into several query
*** windows
***
EXEC CookbookDemo.dbo.sp_ExecuteRandomProc 500
GO 
*** x500 = @3 min
***************************************/


-- Ensure we're on SQL Server 2019 compat
USE Master;
GO
ALTER DATABASE CookbookDemo
	SET COMPATIBILITY_LEVEL = 150;
GO

USE CookbookDemo;
GO

-----
-- Database Scoped Configurations
-- Make sure we're running 2019 defaults
SELECT name, value, is_value_default,
	CASE 
		WHEN database_scoped_configurations.value = 0
		THEN
		'ALTER DATABASE SCOPED CONFIGURATION SET ' + name + ' = ON;'
		WHEN
		database_scoped_configurations.value = 1
		THEN
		'ALTER DATABASE SCOPED CONFIGURATION SET ' + name + ' = OFF;'
	END AS Cmd
FROM sys.database_scoped_configurations
WHERE is_value_default = 0
ORDER BY name;
GO

-----
-- Flush all NCI's - Clustered Indexes only
EXEC dbo.sp_DropAllNCIs @PrintOnly = 0, @RestoreBaseNCIs = 0;
GO