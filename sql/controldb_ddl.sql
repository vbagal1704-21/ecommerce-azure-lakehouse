-- pipeline_watermark: tracks incremental load progress per source table per environment.
-- This table is the single source of truth for "what have we already loaded."
CREATE TABLE pipeline_watermark (
    watermark_id        INT IDENTITY(1,1) PRIMARY KEY,   -- surrogate key, auto-incrementing
    source_table         VARCHAR(100) NOT NULL,           -- e.g. 'orders', 'customers'
    environment           VARCHAR(10)  NOT NULL,           -- 'dev' | 'uat' | 'prod'
    last_watermark_value VARCHAR(100) NOT NULL,           -- stored as string so it can hold a timestamp or a batch id
    watermark_column     VARCHAR(100) NOT NULL,           -- which source column this value came from, for auditability
    updated_at            DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_watermark UNIQUE (source_table, environment)  -- one active watermark row per table per env
);

-- pipeline_audit_log: one row per end-to-end pipeline run, across all layers.
CREATE TABLE pipeline_audit_log (
    run_id                UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),  -- globally unique run identifier, shared across ADF + Databricks
    pipeline_name         VARCHAR(100) NOT NULL,
    environment            VARCHAR(10)  NOT NULL,
    layer                  VARCHAR(20)  NOT NULL,           -- 'bronze' | 'silver' | 'gold'
    source_table            VARCHAR(100),
    status                  VARCHAR(20)  NOT NULL,           -- 'STARTED' | 'SUCCEEDED' | 'FAILED'
    rows_read               BIGINT,
    rows_written             BIGINT,
    start_time              DATETIME2    NOT NULL,
    end_time                DATETIME2,
    error_message           VARCHAR(MAX),
    CONSTRAINT chk_status CHECK (status IN ('STARTED','SUCCEEDED','FAILED'))
);

-- dq_results: one row per data quality rule evaluation per run.
CREATE TABLE dq_results (
    dq_result_id          INT IDENTITY(1,1) PRIMARY KEY,
    run_id                 UNIQUEIDENTIFIER NOT NULL REFERENCES pipeline_audit_log(run_id),
    rule_name               VARCHAR(100) NOT NULL,
    severity                 VARCHAR(10)  NOT NULL,          -- 'ERROR' | 'WARN'
    passed                   BIT          NOT NULL,
    rows_failed              BIGINT,
    checked_at               DATETIME2    NOT NULL DEFAULT SYSUTCDATETIME()
);
   SELECT * FROM pipeline_watermark;