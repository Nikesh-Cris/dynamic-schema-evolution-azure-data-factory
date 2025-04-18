/****** Object:  StoredProcedure [dcm].[usp_dyn_staging_to_final_data_insertion]    Script Date: 18-04-2025 18:32:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dcm].[usp_dyn_staging_to_final_data_insertion] @SchemaName [NVARCHAR](128),@TableName [NVARCHAR](128),@StagingTableName [NVARCHAR](128) AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Fully‑qualified names
    DECLARE 
        @fullMainTable    NVARCHAR(300) = QUOTENAME(@SchemaName)    + '.' + QUOTENAME(@TableName),
        @fullStagingTable NVARCHAR(300) = QUOTENAME(@SchemaName)    + '.' + QUOTENAME(@StagingTableName);

    -- 2) Temp tables for metadata vs staging columns
    IF OBJECT_ID('tempdb..#metadataColumns') IS NOT NULL DROP TABLE #metadataColumns;
    IF OBJECT_ID('tempdb..#stagingColumns')  IS NOT NULL DROP TABLE #stagingColumns;

    CREATE TABLE #metadataColumns (ColumnName NVARCHAR(128));
    CREATE TABLE #stagingColumns  (ColumnName NVARCHAR(128));

    -- 3) Load metadata‑driven column list
    INSERT INTO #metadataColumns (ColumnName)
    SELECT ColumnName
    FROM   dcm.table_metadata
    WHERE  SchemaName = @SchemaName
      AND  TableName  = @TableName;

    -- 4) Load actual staging columns
    INSERT INTO #stagingColumns (ColumnName)
    SELECT COLUMN_NAME
    FROM   INFORMATION_SCHEMA.COLUMNS
    WHERE  TABLE_SCHEMA = @SchemaName
      AND  TABLE_NAME   = @StagingTableName;

    -- 5) Build the two comma‑lists in one go
    DECLARE 
        @columns       NVARCHAR(MAX),
        @selectColumns NVARCHAR(MAX),
        @insertSql     NVARCHAR(MAX);

    SELECT
        @columns =       STRING_AGG( QUOTENAME(mc.ColumnName), ',' ),
        @selectColumns = STRING_AGG(
            CASE 
              WHEN sc.ColumnName IS NOT NULL 
                THEN QUOTENAME(mc.ColumnName)
              ELSE 
                'NULL AS ' + QUOTENAME(mc.ColumnName)
            END
          , ','
        )
    FROM #metadataColumns mc
    LEFT JOIN #stagingColumns sc
      ON mc.ColumnName = sc.ColumnName;

    -- 6) Assemble and execute the INSERT…SELECT
    SET @insertSql = '
    INSERT INTO ' + @fullMainTable + ' (' + @columns + ')
    SELECT '      + @selectColumns + '
    FROM   '      + @fullStagingTable + ';';

    EXEC sp_executesql @insertSql;

    -- 7) Cleanup
    DROP TABLE #metadataColumns;
    DROP TABLE #stagingColumns;
END
GO


