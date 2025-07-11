-- Greenhouse Case Study Database Schema
-- Based on existing Hippo production database structure

-- Create locations table (greenhouse slots - 50x8 grid per greenhouse)
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    house_number INTEGER,
    rail_number INTEGER,
    slot_number INTEGER,
    x_position INTEGER,
    y_position INTEGER,
    is_disabled BOOLEAN NOT NULL DEFAULT FALSE,
    is_removed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT ck_locations_remove_only_if_disabled CHECK (NOT is_removed OR is_removed AND is_disabled)
);

-- Create crop_cycles table (main table for plant lifecycle)
CREATE TABLE crop_cycles (
    id SERIAL PRIMARY KEY,
    seed_id TEXT,
    crop TEXT,
    seed_type TEXT,
    sub_crop TEXT,
    module_id TEXT,
    germination_id TEXT,
    num_plants INTEGER,
    substrate TEXT,
    slot_id TEXT,
    x DOUBLE PRECISION,
    y DOUBLE PRECISION,
    dock_id TEXT,
    seed_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    transplant_timestamp TIMESTAMP WITH TIME ZONE,
    harvest_timestamp TIMESTAMP WITH TIME ZONE,
    clean_timestamp TIMESTAMP WITH TIME ZONE,
    scheduled_seed_timestamp TIMESTAMP WITH TIME ZONE,
    scheduled_transplant_timestamp TIMESTAMP WITH TIME ZONE,
    scheduled_harvest_timestamp TIMESTAMP WITH TIME ZONE,
    fertigation_profile TEXT,
    notes TEXT,
    dispose BOOLEAN NOT NULL DEFAULT FALSE,
    inputs TEXT,
    harvest_weight_g DOUBLE PRECISION,
    cut_height_offset DOUBLE PRECISION NOT NULL DEFAULT 0,
    root INTEGER,
    parent INTEGER,
    child INTEGER,
    cut INTEGER NOT NULL DEFAULT 0,
    harvest_bags JSONB,
    data JSONB,
    harvest_order INTEGER,
    sku TEXT,
    mix BOOLEAN,
    tags JSONB,
    is_organic BOOLEAN,
    sku_group INTEGER,
    harvest_notes TEXT,
    dispose_reasons JSONB,
    completed_timestamp TIMESTAMP WITH TIME ZONE,
    current_location INTEGER REFERENCES locations(id),
    is_experiment BOOLEAN
);

-- Create ml_harvest_predictions table
CREATE TABLE ml_harvest_predictions (
    id SERIAL PRIMARY KEY,
    crop_cycle_id INTEGER REFERENCES crop_cycles(id),
    predicted_harvest_date DATE NOT NULL,
    predicted_yield_g DOUBLE PRECISION NOT NULL,
    days_since_transplant INTEGER NOT NULL,
    confidence_score DOUBLE PRECISION,
    model_version TEXT DEFAULT 'growth_predictor_v3.2',
    prediction_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    features JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crop_cycle_id, predicted_harvest_date)
);

-- Create indexes for performance
CREATE INDEX idx_crop_cycles_crop ON crop_cycles(crop);
CREATE INDEX idx_crop_cycles_scheduled_harvest_timestamp ON crop_cycles(scheduled_harvest_timestamp);
CREATE INDEX idx_crop_cycles_harvest_timestamp ON crop_cycles(harvest_timestamp);
CREATE INDEX idx_crop_cycles_slot_id ON crop_cycles(slot_id);
CREATE INDEX idx_crop_cycles_module_id ON crop_cycles(module_id);
CREATE INDEX idx_crop_cycles_current_location ON crop_cycles(current_location);
CREATE INDEX idx_crop_cycles_seed_timestamp ON crop_cycles(seed_timestamp);
CREATE INDEX idx_crop_cycles_transplant_timestamp ON crop_cycles(transplant_timestamp);
CREATE INDEX idx_locations_house_position ON locations(house_number, x_position, y_position);
CREATE INDEX idx_ml_harvest_predictions_crop_cycle_id ON ml_harvest_predictions(crop_cycle_id);
CREATE INDEX idx_ml_harvest_predictions_predicted_harvest_date ON ml_harvest_predictions(predicted_harvest_date);

-- Create views for common queries
CREATE VIEW ready_for_harvest AS
SELECT 
    cc.id,
    cc.module_id,
    cc.crop,
    cc.sub_crop,
    cc.scheduled_harvest_timestamp,
    cc.num_plants,
    cc.slot_id,
    cc.harvest_weight_g,
    l.name as location_name,
    l.house_number,
    l.x_position,
    l.y_position,
    CASE 
        WHEN cc.scheduled_harvest_timestamp <= CURRENT_TIMESTAMP THEN 'overdue'
        WHEN cc.scheduled_harvest_timestamp <= CURRENT_TIMESTAMP + INTERVAL '3 days' THEN 'ready'
        ELSE 'upcoming'
    END as harvest_urgency,
    mhp.predicted_yield_g as ml_predicted_yield_g,
    mhp.confidence_score as ml_confidence_score,
    mhp.days_since_transplant as ml_days_since_transplant
FROM crop_cycles cc
LEFT JOIN locations l ON cc.current_location = l.id
LEFT JOIN ml_harvest_predictions mhp ON cc.id = mhp.crop_cycle_id 
    AND DATE(cc.scheduled_harvest_timestamp) = mhp.predicted_harvest_date
WHERE cc.harvest_timestamp IS NULL 
AND cc.dispose = FALSE
AND cc.scheduled_harvest_timestamp IS NOT NULL;

CREATE VIEW harvest_planning AS
SELECT 
    DATE(cc.scheduled_harvest_timestamp) as harvest_date,
    COUNT(*) as modules_ready,
    SUM(cc.num_plants) as total_plants,
    SUM(cc.harvest_weight_g) as estimated_yield_g,
    AVG(mhp.predicted_yield_g) as avg_ml_predicted_yield_g,
    AVG(mhp.confidence_score) as avg_ml_confidence_score,
    cc.crop,
    STRING_AGG(DISTINCT cc.sub_crop, ', ') as varieties
FROM crop_cycles cc
LEFT JOIN ml_harvest_predictions mhp ON cc.id = mhp.crop_cycle_id 
    AND DATE(cc.scheduled_harvest_timestamp) = mhp.predicted_harvest_date
WHERE cc.harvest_timestamp IS NULL 
AND cc.dispose = FALSE
AND cc.scheduled_harvest_timestamp BETWEEN CURRENT_TIMESTAMP AND CURRENT_TIMESTAMP + INTERVAL '14 days'
GROUP BY DATE(cc.scheduled_harvest_timestamp), cc.crop
ORDER BY harvest_date;

CREATE VIEW greenhouse_occupancy AS
SELECT 
    l.house_number,
    COUNT(l.id) as total_slots,
    COUNT(cc.id) as occupied_slots,
    COUNT(l.id) - COUNT(cc.id) as empty_slots,
    ROUND((COUNT(cc.id)::DECIMAL / COUNT(l.id) * 100), 2) as occupancy_percent
FROM locations l
LEFT JOIN crop_cycles cc ON l.id = cc.current_location AND cc.harvest_timestamp IS NULL AND cc.dispose = FALSE
WHERE l.type = 'slot'
GROUP BY l.house_number
ORDER BY l.house_number;

CREATE VIEW greenhouse_layout AS
WITH greenhouse_grid AS (
    SELECT 
        l.house_number,
        l.x_position,
        l.y_position,
        CASE 
            WHEN cc.id IS NOT NULL THEN 
                CASE 
                    WHEN cc.crop = 'LETTUCE' THEN 'L'
                    WHEN cc.crop = 'SPINACH' THEN 'S'
                    WHEN cc.crop = 'ARUGULA' THEN 'A'
                    WHEN cc.crop = 'KALE' THEN 'K'
                    ELSE 'X'
                END
            ELSE ' '
        END as occupancy_symbol
    FROM locations l
    LEFT JOIN crop_cycles cc ON l.id = cc.current_location 
        AND cc.harvest_timestamp IS NULL 
        AND cc.dispose = FALSE
    WHERE l.type = 'slot'
)
SELECT 
    house_number,
    y_position as row_number,
    'GH' || house_number || ' Row ' || y_position || ':' as greenhouse_row,
    string_agg(occupancy_symbol, '' ORDER BY x_position) as layout_columns_1_to_50
FROM greenhouse_grid
GROUP BY house_number, y_position
ORDER BY house_number, y_position;

CREATE VIEW crop_growth_analysis AS
SELECT 
    cc.id as crop_cycle_id,
    cc.crop,
    cc.sub_crop,
    cc.num_plants,
    cc.transplant_timestamp,
    cc.scheduled_harvest_timestamp,
    CURRENT_DATE - DATE(cc.transplant_timestamp) as current_days_since_transplant,
    mhp_current.predicted_yield_g as current_predicted_yield_g,
    mhp_current.confidence_score as current_confidence_score,
    mhp_optimal.predicted_harvest_date as optimal_harvest_date,
    mhp_optimal.predicted_yield_g as optimal_predicted_yield_g,
    mhp_optimal.confidence_score as optimal_confidence_score,
    mhp_optimal.days_since_transplant as optimal_days_since_transplant
FROM crop_cycles cc
LEFT JOIN ml_harvest_predictions mhp_current ON cc.id = mhp_current.crop_cycle_id 
    AND mhp_current.predicted_harvest_date = CURRENT_DATE
LEFT JOIN ml_harvest_predictions mhp_optimal ON cc.id = mhp_optimal.crop_cycle_id 
    AND mhp_optimal.id = (
        SELECT id FROM ml_harvest_predictions 
        WHERE crop_cycle_id = cc.id 
        ORDER BY predicted_yield_g DESC 
        LIMIT 1
    )
WHERE cc.harvest_timestamp IS NULL 
AND cc.dispose = FALSE
AND cc.transplant_timestamp IS NOT NULL;

CREATE VIEW harvest_forecast AS
SELECT 
    mhp.predicted_harvest_date,
    mhp.crop_cycle_id,
    cc.crop,
    cc.sub_crop,
    cc.module_id,
    cc.slot_id,
    cc.num_plants,
    mhp.predicted_yield_g,
    mhp.confidence_score,
    mhp.days_since_transplant,
    l.house_number,
    l.x_position,
    l.y_position,
    CASE 
        WHEN mhp.predicted_harvest_date = CURRENT_DATE THEN 'today'
        WHEN mhp.predicted_harvest_date = CURRENT_DATE + INTERVAL '1 day' THEN 'tomorrow'
        WHEN mhp.predicted_harvest_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'this_week'
        WHEN mhp.predicted_harvest_date <= CURRENT_DATE + INTERVAL '14 days' THEN 'next_week'
        ELSE 'future'
    END as harvest_timeframe
FROM ml_harvest_predictions mhp
JOIN crop_cycles cc ON mhp.crop_cycle_id = cc.id
LEFT JOIN locations l ON cc.current_location = l.id
WHERE cc.harvest_timestamp IS NULL 
AND cc.dispose = FALSE
AND mhp.predicted_harvest_date >= CURRENT_DATE
ORDER BY mhp.predicted_harvest_date, mhp.predicted_yield_g DESC;