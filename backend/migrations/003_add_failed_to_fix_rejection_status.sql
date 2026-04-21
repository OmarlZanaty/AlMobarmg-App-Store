DO $$ BEGIN
  ALTER TYPE fix_rejection_status ADD VALUE IF NOT EXISTS 'failed';
EXCEPTION WHEN duplicate_object THEN null;
END $$;
