-- Greenhouse Case Study Mock Data
-- 3 Greenhouses with 50x8 grids (400 slots each, 1200 total)
-- ~10% empty slots (1080 occupied, 120 empty)

-- Insert locations for 3 greenhouses (50x8 grid each)
DO $$
DECLARE
    house_num INTEGER;
    x_pos INTEGER;
    y_pos INTEGER;
    slot_count INTEGER := 0;
BEGIN
    -- Generate slots for 3 greenhouses
    FOR house_num IN 1..3 LOOP
        FOR x_pos IN 1..50 LOOP
            FOR y_pos IN 1..8 LOOP
                slot_count := slot_count + 1;
                INSERT INTO locations (name, type, house_number, rail_number, slot_number, x_position, y_position, is_disabled, is_removed)
                VALUES (
                    'slot_' || house_num || '_' || LPAD(x_pos::TEXT, 2, '0') || '_' || LPAD(y_pos::TEXT, 2, '0'),
                    'slot',
                    house_num,
                    y_pos,
                    slot_count,
                    x_pos,
                    y_pos,
                    FALSE,
                    FALSE
                );
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- Add germination and staging areas
INSERT INTO locations (name, type, house_number, rail_number, slot_number, x_position, y_position, is_disabled, is_removed) VALUES
('germination_area_1', 'germination', NULL, NULL, NULL, NULL, NULL, FALSE, FALSE),
('germination_area_2', 'germination', NULL, NULL, NULL, NULL, NULL, FALSE, FALSE),
('germination_area_3', 'germination', NULL, NULL, NULL, NULL, NULL, FALSE, FALSE),
('harvesting_station_1', 'staging', NULL, NULL, NULL, NULL, NULL, FALSE, FALSE),
('harvesting_station_2', 'staging', NULL, NULL, NULL, NULL, NULL, FALSE, FALSE),
('packaging_area', 'staging', NULL, NULL, NULL, NULL, NULL, FALSE, FALSE);

-- Generate crop cycles for ~90% occupancy (1080 out of 1200 slots)
-- This creates realistic distribution across the 3 greenhouses
DO $$
DECLARE
    loc_record RECORD;
    crop_types TEXT[] := ARRAY['LETTUCE', 'SPINACH', 'ARUGULA', 'KALE'];
    lettuce_varieties TEXT[] := ARRAY['Tropicana Green Leaf', 'Starstruck', 'Green Forest', 'Coastline (ORGANIC)', 'Butter Crunch'];
    spinach_varieties TEXT[] := ARRAY['Gerenuk', 'Sunangel', 'Tarsier', 'Space (ORGANIC)', 'Bloomsdale'];
    arugula_varieties TEXT[] := ARRAY['Wild Rocket', 'Astro', 'Sylvetta'];
    kale_varieties TEXT[] := ARRAY['Red Russian', 'Winterbor', 'Dwarf Blue Curled'];
    
    selected_crop TEXT;
    selected_variety TEXT;
    seed_date TIMESTAMP;
    transplant_date TIMESTAMP;
    harvest_date TIMESTAMP;
    slot_count INTEGER := 0;
    skip_slot BOOLEAN;
    
BEGIN
    -- Iterate through locations and populate ~90% with crops
    FOR loc_record IN 
        SELECT id, name, house_number, x_position, y_position 
        FROM locations 
        WHERE type = 'slot' 
        ORDER BY house_number, x_position, y_position
    LOOP
        slot_count := slot_count + 1;
        
        -- Skip roughly 10% of slots to create empty spaces
        skip_slot := (slot_count % 10 = 0 AND random() < 0.5) OR 
                    (slot_count % 15 = 0) OR
                    (slot_count % 23 = 0 AND random() < 0.3);
        
        IF NOT skip_slot THEN
            -- Select crop type and variety
            selected_crop := crop_types[1 + floor(random() * array_length(crop_types, 1))];
            
            CASE selected_crop
                WHEN 'LETTUCE' THEN
                    selected_variety := lettuce_varieties[1 + floor(random() * array_length(lettuce_varieties, 1))];
                WHEN 'SPINACH' THEN
                    selected_variety := spinach_varieties[1 + floor(random() * array_length(spinach_varieties, 1))];
                WHEN 'ARUGULA' THEN
                    selected_variety := arugula_varieties[1 + floor(random() * array_length(arugula_varieties, 1))];
                WHEN 'KALE' THEN
                    selected_variety := kale_varieties[1 + floor(random() * array_length(kale_varieties, 1))];
            END CASE;
            
            -- Generate realistic timestamps - all crops are still growing, none ready for harvest
            seed_date := CURRENT_TIMESTAMP - (random() * 30 || ' days')::INTERVAL; -- Seeds planted within last 30 days
            transplant_date := seed_date + (7 + random() * 7 || ' days')::INTERVAL; -- 7-14 days after seed
            
            -- Different harvest timing based on crop type - all harvest dates are in the future
            CASE selected_crop
                WHEN 'LETTUCE' THEN
                    harvest_date := transplant_date + (35 + random() * 10 || ' days')::INTERVAL;
                WHEN 'SPINACH' THEN
                    harvest_date := transplant_date + (25 + random() * 10 || ' days')::INTERVAL;
                WHEN 'ARUGULA' THEN
                    harvest_date := transplant_date + (20 + random() * 10 || ' days')::INTERVAL;
                WHEN 'KALE' THEN
                    harvest_date := transplant_date + (40 + random() * 15 || ' days')::INTERVAL;
            END CASE;
            
            -- Ensure harvest date is well in the future (at least 5 days from now)
            IF harvest_date <= CURRENT_TIMESTAMP + INTERVAL '5 days' THEN
                harvest_date := CURRENT_TIMESTAMP + (10 + random() * 30 || ' days')::INTERVAL;
            END IF;
            
            -- Insert crop cycle
            INSERT INTO crop_cycles (
                seed_id,
                crop,
                seed_type,
                sub_crop,
                module_id,
                germination_id,
                num_plants,
                substrate,
                slot_id,
                x,
                y,
                dock_id,
                seed_timestamp,
                transplant_timestamp,
                scheduled_harvest_timestamp,
                scheduled_seed_timestamp,
                scheduled_transplant_timestamp,
                fertigation_profile,
                dispose,
                harvest_weight_g,
                current_location
            ) VALUES (
                'SEED-' || selected_crop || '-' || EXTRACT(YEAR FROM seed_date) || '-' || LPAD(slot_count::TEXT, 6, '0'),
                selected_crop,
                'PELLETED',
                selected_variety,
                'module_' || loc_record.house_number || '_' || LPAD(loc_record.x_position::TEXT, 2, '0') || '_' || LPAD(loc_record.y_position::TEXT, 2, '0'),
                'germ_batch_' || (1 + floor(random() * 10))::TEXT,
                CASE 
                    WHEN selected_crop = 'LETTUCE' THEN 600 + floor(random() * 400)
                    WHEN selected_crop = 'SPINACH' THEN 800 + floor(random() * 400)
                    WHEN selected_crop = 'ARUGULA' THEN 900 + floor(random() * 300)
                    WHEN selected_crop = 'KALE' THEN 500 + floor(random() * 300)
                END,
                'CUSTOM',
                loc_record.name,
                14.5 + (random() * 2),
                loc_record.y_position + (random() * 0.5),
                loc_record.name,
                seed_date,
                transplant_date,
                NULL,
                seed_date - (random() * 2 || ' days')::INTERVAL, -- scheduled_seed_timestamp: 0-2 days before actual
                transplant_date - (random() * 2 || ' days')::INTERVAL, -- scheduled_transplant_timestamp: 0-2 days before actual
                'profile_' || lower(selected_crop) || '_standard',
                FALSE,
                NULL,
                loc_record.id
            );
        END IF;
    END LOOP;
END $$;

-- Generate 5000 harvested crop cycles (completed lifecycle)
DO $$
DECLARE
    crop_types TEXT[] := ARRAY['LETTUCE', 'SPINACH', 'ARUGULA', 'KALE'];
    lettuce_varieties TEXT[] := ARRAY['Tropicana Green Leaf', 'Starstruck', 'Green Forest', 'Coastline (ORGANIC)', 'Butter Crunch'];
    spinach_varieties TEXT[] := ARRAY['Gerenuk', 'Sunangel', 'Tarsier', 'Space (ORGANIC)', 'Bloomsdale'];
    arugula_varieties TEXT[] := ARRAY['Wild Rocket', 'Astro', 'Sylvetta'];
    kale_varieties TEXT[] := ARRAY['Red Russian', 'Winterbor', 'Dwarf Blue Curled'];
    
    selected_crop TEXT;
    selected_variety TEXT;
    scheduled_seed_date TIMESTAMP;
    actual_seed_date TIMESTAMP;
    scheduled_transplant_date TIMESTAMP;
    actual_transplant_date TIMESTAMP;
    scheduled_harvest_date TIMESTAMP;
    actual_harvest_date TIMESTAMP;
    clean_date TIMESTAMP;
    completed_date TIMESTAMP;
    i INTEGER;
    
BEGIN
    -- Generate 5000 completed crop cycles
    FOR i IN 1..5000 LOOP
        -- Select crop type and variety
        selected_crop := crop_types[1 + floor(random() * array_length(crop_types, 1))];
        
        CASE selected_crop
            WHEN 'LETTUCE' THEN
                selected_variety := lettuce_varieties[1 + floor(random() * array_length(lettuce_varieties, 1))];
            WHEN 'SPINACH' THEN
                selected_variety := spinach_varieties[1 + floor(random() * array_length(spinach_varieties, 1))];
            WHEN 'ARUGULA' THEN
                selected_variety := arugula_varieties[1 + floor(random() * array_length(arugula_varieties, 1))];
            WHEN 'KALE' THEN
                selected_variety := kale_varieties[1 + floor(random() * array_length(kale_varieties, 1))];
        END CASE;
        
        -- Generate historical timestamps (completed crops from last 6 months)
        scheduled_seed_date := CURRENT_TIMESTAMP - (30 + random() * 150 || ' days')::INTERVAL; -- 30-180 days ago
        actual_seed_date := scheduled_seed_date + (random() * 3 || ' days')::INTERVAL; -- 0-3 days after scheduled
        
        scheduled_transplant_date := scheduled_seed_date + (7 + random() * 7 || ' days')::INTERVAL; -- 7-14 days after scheduled seed
        actual_transplant_date := scheduled_transplant_date + (random() * 3 || ' days')::INTERVAL; -- 0-3 days after scheduled
        
        -- Different harvest timing based on crop type
        CASE selected_crop
            WHEN 'LETTUCE' THEN
                scheduled_harvest_date := scheduled_transplant_date + (35 + random() * 10 || ' days')::INTERVAL;
            WHEN 'SPINACH' THEN
                scheduled_harvest_date := scheduled_transplant_date + (25 + random() * 10 || ' days')::INTERVAL;
            WHEN 'ARUGULA' THEN
                scheduled_harvest_date := scheduled_transplant_date + (20 + random() * 10 || ' days')::INTERVAL;
            WHEN 'KALE' THEN
                scheduled_harvest_date := scheduled_transplant_date + (40 + random() * 15 || ' days')::INTERVAL;
        END CASE;
        
        actual_harvest_date := scheduled_harvest_date + (random() * 5 - 2 || ' days')::INTERVAL; -- +/- 2 days from scheduled
        clean_date := actual_harvest_date + (1 + random() * 3 || ' hours')::INTERVAL; -- 1-4 hours after harvest
        completed_date := clean_date + (30 + random() * 60 || ' minutes')::INTERVAL; -- 30-90 minutes after clean
        
        -- Insert harvested crop cycle
        INSERT INTO crop_cycles (
            seed_id,
            crop,
            seed_type,
            sub_crop,
            module_id,
            germination_id,
            num_plants,
            substrate,
            slot_id,
            x,
            y,
            dock_id,
            seed_timestamp,
            transplant_timestamp,
            harvest_timestamp,
            clean_timestamp,
            completed_timestamp,
            scheduled_seed_timestamp,
            scheduled_transplant_timestamp,
            scheduled_harvest_timestamp,
            fertigation_profile,
            dispose,
            harvest_weight_g,
            current_location -- NULL for harvested crops
        ) VALUES (
            'SEED-' || selected_crop || '-HARVESTED-' || EXTRACT(YEAR FROM actual_seed_date) || '-' || LPAD(i::TEXT, 6, '0'),
            selected_crop,
            'PELLETED',
            selected_variety,
            'harvested_module_' || LPAD(i::TEXT, 6, '0'),
            'germ_batch_' || (1 + floor(random() * 20))::TEXT,
            CASE 
                WHEN selected_crop = 'LETTUCE' THEN 600 + floor(random() * 400)
                WHEN selected_crop = 'SPINACH' THEN 800 + floor(random() * 400)
                WHEN selected_crop = 'ARUGULA' THEN 900 + floor(random() * 300)
                WHEN selected_crop = 'KALE' THEN 500 + floor(random() * 300)
            END,
            'CUSTOM',
            'harvested_slot_' || LPAD(i::TEXT, 6, '0'),
            14.5 + (random() * 2),
            1 + floor(random() * 8),
            'harvested_slot_' || LPAD(i::TEXT, 6, '0'),
            actual_seed_date,
            actual_transplant_date,
            actual_harvest_date,
            clean_date,
            completed_date,
            scheduled_seed_date,
            scheduled_transplant_date,
            scheduled_harvest_date,
            'profile_' || lower(selected_crop) || '_standard',
            FALSE,
            CASE 
                WHEN selected_crop = 'LETTUCE' THEN 3000 + floor(random() * 2000) -- 3-5kg actual yield
                WHEN selected_crop = 'SPINACH' THEN 2200 + floor(random() * 1300) -- 2.2-3.5kg actual yield
                WHEN selected_crop = 'ARUGULA' THEN 1800 + floor(random() * 1000) -- 1.8-2.8kg actual yield
                WHEN selected_crop = 'KALE' THEN 2500 + floor(random() * 1500) -- 2.5-4kg actual yield
            END,
            NULL -- No current location for harvested crops
        );
    END LOOP;
END $$;

-- Generate ML harvest predictions for all active crops
-- Each crop gets predictions for multiple possible harvest dates with growth curves
DO $$
DECLARE
    crop_record RECORD;
    harvest_day DATE;
    days_since_transplant INTEGER;
    base_yield_g DOUBLE PRECISION;
    predicted_yield_g DOUBLE PRECISION;
    growth_factor DOUBLE PRECISION;
    confidence DOUBLE PRECISION;
    min_harvest_date DATE;
    max_harvest_date DATE;
    crop_maturity_days INTEGER;
    
BEGIN
    -- Loop through all active crop cycles
    FOR crop_record IN 
        SELECT id, crop, transplant_timestamp, harvest_weight_g, num_plants, current_location, scheduled_harvest_timestamp
        FROM crop_cycles 
        WHERE harvest_timestamp IS NULL AND dispose = FALSE AND transplant_timestamp IS NOT NULL
    LOOP
        -- Determine crop-specific maturity timeline
        CASE crop_record.crop
            WHEN 'LETTUCE' THEN
                crop_maturity_days := 35;
            WHEN 'SPINACH' THEN
                crop_maturity_days := 25;
            WHEN 'ARUGULA' THEN
                crop_maturity_days := 20;
            WHEN 'KALE' THEN
                crop_maturity_days := 40;
            ELSE
                crop_maturity_days := 30;
        END CASE;
        
        -- Calculate harvest date range (from 10 days after transplant to maturity + 20 days)
        min_harvest_date := DATE(crop_record.transplant_timestamp + INTERVAL '10 days');
        max_harvest_date := DATE(crop_record.transplant_timestamp + (crop_maturity_days + 20 || ' days')::INTERVAL);
        
        -- Generate base yield (what the crop would yield at maturity)
        -- For active crops, harvest_weight_g is NULL, so use expected yield by crop type
        IF crop_record.harvest_weight_g IS NOT NULL THEN
            base_yield_g := crop_record.harvest_weight_g * (0.9 + random() * 0.2); -- Add some variance
        ELSE
            -- Use expected yield ranges for each crop type when harvest_weight_g is NULL
            CASE crop_record.crop
                WHEN 'LETTUCE' THEN
                    base_yield_g := 3000 + floor(random() * 2000); -- 3-5kg expected
                WHEN 'SPINACH' THEN
                    base_yield_g := 2200 + floor(random() * 1300); -- 2.2-3.5kg expected
                WHEN 'ARUGULA' THEN
                    base_yield_g := 1800 + floor(random() * 1000); -- 1.8-2.8kg expected
                WHEN 'KALE' THEN
                    base_yield_g := 2500 + floor(random() * 1500); -- 2.5-4kg expected
                ELSE
                    base_yield_g := 2500 + floor(random() * 1000); -- Default range
            END CASE;
        END IF;
        
        -- Generate predictions for each possible harvest date
        harvest_day := min_harvest_date;
        WHILE harvest_day <= max_harvest_date LOOP
            days_since_transplant := (harvest_day - DATE(crop_record.transplant_timestamp))::INTEGER;
            
            -- Growth curve: rapid growth until day 21, then plateaus
            IF days_since_transplant <= 21 THEN
                -- Sigmoid growth curve: starts slow, accelerates, then slows as it approaches maturity
                growth_factor := 1 / (1 + exp(-0.3 * (days_since_transplant - 15)));
            ELSE
                -- After day 21, growth plateaus with slight continued increase
                growth_factor := 1 / (1 + exp(-0.3 * (21 - 15))) + (days_since_transplant - 21) * 0.01;
            END IF;
            
            -- Calculate predicted yield based on growth curve
            predicted_yield_g := base_yield_g * growth_factor;
            
            -- Ensure minimum yield (can't be negative or too small)
            IF predicted_yield_g < base_yield_g * 0.1 THEN
                predicted_yield_g := base_yield_g * 0.1;
            END IF;
            
            -- Confidence score: higher for dates closer to optimal harvest, lower for very early/late
            IF days_since_transplant < 15 THEN
                confidence := 0.3 + (days_since_transplant::FLOAT / 15) * 0.4; -- 0.3 to 0.7
            ELSIF days_since_transplant <= crop_maturity_days + 5 THEN
                confidence := 0.85 + random() * 0.1; -- 0.85 to 0.95 (peak confidence)
            ELSE
                confidence := 0.95 - ((days_since_transplant - crop_maturity_days - 5)::FLOAT / 15) * 0.35; -- declining confidence
            END IF;
            
            -- Ensure confidence stays within bounds
            confidence := GREATEST(0.2, LEAST(0.95, confidence));
            
            -- Insert prediction
            INSERT INTO ml_harvest_predictions (
                crop_cycle_id,
                predicted_harvest_date,
                predicted_yield_g,
                days_since_transplant,
                confidence_score,
                model_version,
                features
            ) VALUES (
                crop_record.id,
                harvest_day,
                ROUND(predicted_yield_g::DECIMAL, 1),
                days_since_transplant,
                ROUND(confidence::DECIMAL, 3),
                'growth_predictor_v3.2',
                jsonb_build_object(
                    'plant_count', crop_record.num_plants,
                    'crop_type', crop_record.crop,
                    'days_since_transplant', days_since_transplant,
                    'greenhouse', (SELECT house_number FROM locations WHERE id = crop_record.current_location),
                    'growth_factor', ROUND(growth_factor::DECIMAL, 3),
                    'base_yield_g', ROUND(base_yield_g::DECIMAL, 1),
                    'maturity_days', crop_maturity_days
                )
            );
            
            harvest_day := harvest_day + INTERVAL '1 day';
        END LOOP;
    END LOOP;
END $$;