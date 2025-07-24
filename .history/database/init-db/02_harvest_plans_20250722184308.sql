-- Create harvest_plans table for storing user harvest selections
CREATE TABLE IF NOT EXISTS harvest_plans (
    id SERIAL PRIMARY KEY,
    target_date DATE NOT NULL,
    crop_cycle_id INTEGER REFERENCES crop_cycles(id),
    crop_type VARCHAR(50) NOT NULL,
    sub_crop VARCHAR(100),
    planned_yield_g INTEGER,
    confidence_score DECIMAL(3,2),
    house_number INTEGER,
    location_x INTEGER,
    location_y INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for efficient date-based queries
CREATE INDEX IF NOT EXISTS idx_harvest_plans_date ON harvest_plans(target_date);

-- Create index for crop cycle lookups
CREATE INDEX IF NOT EXISTS idx_harvest_plans_crop_cycle ON harvest_plans(crop_cycle_id);

-- Add comment to table
COMMENT ON TABLE harvest_plans IS 'User-created harvest plans for specific dates'; 