-- Fix missing database columns for Flow-Space backend
-- Run this script to fix schema issues

-- Fix 1: Check if uploaded_at column exists in repository_files and add if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'repository_files' 
        AND column_name = 'uploaded_at'
    ) THEN
        ALTER TABLE repository_files ADD COLUMN uploaded_at TIMESTAMP DEFAULT NOW();
        RAISE NOTICE '✅ Added uploaded_at column to repository_files table';
    ELSE
        RAISE NOTICE 'ℹ️ uploaded_at column already exists in repository_files table';
    END IF;
END $$;

-- Fix 2: Check if signer_id column exists in digital_signatures and add if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'digital_signatures' 
        AND column_name = 'signer_id'
    ) THEN
        ALTER TABLE digital_signatures ADD COLUMN signer_id UUID REFERENCES users(id);
        RAISE NOTICE '✅ Added signer_id column to digital_signatures table';
    ELSE
        RAISE NOTICE 'ℹ️ signer_id column already exists in digital_signatures table';
    END IF;
END $$;

-- Fix 3: Check if export_format column exists in report_exports and add if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'report_exports' 
        AND column_name = 'export_format'
    ) THEN
        ALTER TABLE report_exports ADD COLUMN export_format VARCHAR(50) DEFAULT 'pdf';
        RAISE NOTICE '✅ Added export_format column to report_exports table';
    ELSE
        RAISE NOTICE 'ℹ️ export_format column already exists in report_exports table';
    END IF;
END $$;

-- Fix 4: Update any existing records to have default values
UPDATE repository_files SET uploaded_at = NOW() WHERE uploaded_at IS NULL;
UPDATE digital_signatures SET signer_id = (SELECT created_by FROM sign_off_reports WHERE id = digital_signatures.report_id LIMIT 1) WHERE signer_id IS NULL;
UPDATE report_exports SET export_format = 'pdf' WHERE export_format IS NULL;

-- Show current table structures
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('repository_files', 'digital_signatures', 'report_exports')
ORDER BY table_name, ordinal_position;

RAISE NOTICE '🎉 Database schema fixes completed successfully!';
