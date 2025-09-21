-- Database initialization script for Discourse local testing
-- This script runs when the PostgreSQL container starts

-- Create the vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Set proper encoding and locale
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE discourse TO discourse;
GRANT ALL PRIVILEGES ON SCHEMA public TO discourse;

-- Set search path
SET search_path = public, pg_catalog;

-- Ensure proper timezone
SET timezone = 'UTC';

