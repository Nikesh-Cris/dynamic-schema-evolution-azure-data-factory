/****** Object:  StoredProcedure [dbo].[sp_dynamic_stg_table_creation]    Script Date: 18-04-2025 18:40:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[sp_dynamic_stg_table_creation] @SchemaName [NVARCHAR](128),@StagingTableName [NVARCHAR](128),@ColumnList [NVARCHAR](MAX) AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @col NVARCHAR(MAX), @columns NVARCHAR(MAX) = '';
    DECLARE @pos INT = 1;

    -- Build column definitions
    WHILE @pos <= LEN(@ColumnList)
    BEGIN
        SET @col = LTRIM(RTRIM(SUBSTRING(@ColumnList, @pos, CHARINDEX(',', @ColumnList + ',', @pos) - @pos)));
        SET @columns += QUOTENAME(@col) + ' NVARCHAR(200),';
        SET @pos = CHARINDEX(',', @ColumnList + ',', @pos) + 1;
        IF @pos = 1 BREAK;
    END

    -- Remove trailing comma
    SET @columns = LEFT(@columns, LEN(@columns) - 1);

    -- Build SQL with dynamic schema + table
    SET @sql = '
    IF OBJECT_ID(''' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@StagingTableName) + ''', ''U'') IS NOT NULL
        DROP TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@StagingTableName) + ';

    CREATE TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@StagingTableName) + ' (
        ' + @columns + '
    );';

    EXEC sp_executesql @sql;
END

 
GO
