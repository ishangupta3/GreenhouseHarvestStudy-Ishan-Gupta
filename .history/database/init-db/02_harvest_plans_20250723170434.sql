-- Create harvest_plans table for storing user harvest selections
-- This table enables interactive harvest planning by allowing users to
-- select crops from ML predictions and track progress toward 4kg daily targets
CREATE TABLE IF NOT EXISTS harvest_plans (
    id SERIAL PRIMARY KEY,
    target_date DATE NOT NULL,                    -- Target harvest date
    crop_cycle_id INTEGER REFERENCES crop_cycles(id), -- Link to crop data
    crop_type VARCHAR(50) NOT NULL,               -- LETTUCE, ARUGULA, SPINACH, KALE
    sub_crop VARCHAR(100),                        -- Specific variety
    planned_yield_g INTEGER,                      -- Expected yield from ML predictions
    confidence_score DECIMAL(3,2),                -- ML model confidence (0.0-1.0)
    house_number INTEGER,                         -- Greenhouse house (1-3)
    location_x INTEGER,                           -- X position in 50x8 grid
    location_y INTEGER,                           -- Y position in 50x8 grid
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- When crop was added to plan
);

-- Create index for efficient date-based queries
CREATE INDEX IF NOT EXISTS idx_harvest_plans_date ON harvest_plans(target_date);

-- Create index for crop cycle lookups
CREATE INDEX IF NOT EXISTS idx_harvest_plans_crop_cycle ON harvest_plans(crop_cycle_id);

-- Add comment to table
COMMENT ON TABLE harvest_plans IS 'User-created harvest plans for specific dates'; 