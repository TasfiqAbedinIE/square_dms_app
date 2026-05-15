ALTER TABLE public."skillMatrixRecords"
ADD COLUMN IF NOT EXISTS "processSequence" integer;

WITH numbered AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY "referenceNumber"
      ORDER BY id
    ) AS sequence_number
  FROM public."skillMatrixRecords"
  WHERE "processSequence" IS NULL OR "processSequence" = 0
)
UPDATE public."skillMatrixRecords" AS records
SET "processSequence" = numbered.sequence_number
FROM numbered
WHERE records.id = numbered.id;

CREATE INDEX IF NOT EXISTS skill_matrix_records_sequence_idx
ON public."skillMatrixRecords" (
  "referenceNumber",
  "lineNumber",
  "processSequence",
  id
);
