# Dynamic-schema-evolution-azure-data-factory

The pipeline accepts source and sink as parameters
Fully metadata-driven - can ingest and load into any table dynamically during the call

And it handles real-world data changes,

✅ Reads source schema dynamically and compares it with the sink
✅ If a column is missing in the source, we fill NULL values
✅ If a metadata is changed in the source, we alter the sink table to ingest the changed metadata
✅ Then load the data — cleanly and without manual intervention


This is Perfect for handling:

Evolving data sources
Schema drift in data lakes
Automation in metadata-driven pipelines
