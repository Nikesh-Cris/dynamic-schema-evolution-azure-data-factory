SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[sp_dyn_columns_comparison] @SchemaName [NVARCHAR](100),@TableName [NVARCHAR](100),@StagingTableName [NVARCHAR](100) AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @fullMainTable    NVARCHAR(300) = QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName),
        @fullStagingTable NVARCHAR(300) = QUOTENAME(@SchemaName) + '.' + QUOTENAME(@StagingTableName),
        @sql              NVARCHAR(MAX);

    -- 1) Gather new columns
    IF OBJECT_ID('tempdb..#NewColumns') IS NOT NULL DROP TABLE #NewColumns;
    SELECT COLUMN_NAME, DATA_TYPE
    INTO   #NewColumns
    FROM   INFORMATION_SCHEMA.COLUMNS
    WHERE  TABLE_SCHEMA = @SchemaName
      AND  TABLE_NAME   = @StagingTableName
      AND  COLUMN_NAME NOT IN (
            SELECT COLUMN_NAME
            FROM   INFORMATION_SCHEMA.COLUMNS
            WHERE  TABLE_SCHEMA = @SchemaName
              AND  TABLE_NAME   = @TableName
      );

    -- 2) Build dynamic ALTER + metadata INSERT … SELECT
    SELECT @sql = STRING_AGG(
    '
IF NOT EXISTS (
    SELECT 1
    FROM   INFORMATION_SCHEMA.COLUMNS
    WHERE  TABLE_SCHEMA = ''' + @SchemaName + '''
      AND  TABLE_NAME   = ''' + @TableName  + '''
      AND  COLUMN_NAME  = ''' + COLUMN_NAME + '''
)
BEGIN
    ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + '
        ADD ' + QUOTENAME(COLUMN_NAME) + ' NVARCHAR(200);

    INSERT INTO dbo.table_metadata
        (SchemaName, TableName, ColumnName, DataType, CreatedOn)
    SELECT
        ''' + @SchemaName + ''',
        ''' + @TableName  + ''',
        ''' + COLUMN_NAME + ''',
        ''' + DATA_TYPE   + ''',
        GETDATE();
END;'
    , CHAR(10)
)
FROM #NewColumns;


    -- 3) Execute it
    EXEC sp_executesql @sql;

    DROP TABLE #NewColumns;
END

BEGIN
    SET NOCOUNT ON;


    -- 2) Temp tables for metadata vs staging columns
    IF OBJECT_ID('tempdb..#metadataColumns') IS NOT NULL DROP TABLE #metadataColumns;
    IF OBJECT_ID('tempdb..#stagingColumns')  IS NOT NULL DROP TABLE #stagingColumns;

    CREATE TABLE #metadataColumns (ColumnName NVARCHAR(128));
    CREATE TABLE #stagingColumns  (ColumnName NVARCHAR(128));

    -- 3) Load metadata‑driven column list
    INSERT INTO #metadataColumns (ColumnName)
    SELECT ColumnName
    FROM   dbo.table_metadata
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
