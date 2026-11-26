-- Eén postgres, per component een eigen database (spiegelt OpenFSC: manager en
-- controller delen geen DB — beide hebben een public.schema_migrations).
CREATE DATABASE fsc_directory;
CREATE DATABASE fsc_moza;
CREATE DATABASE fsc_controller_moza;
CREATE DATABASE fsc_txlog_moza;
