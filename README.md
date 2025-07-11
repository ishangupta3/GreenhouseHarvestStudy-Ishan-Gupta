# Greenhouse Harvest Planning Case Study

## Overview
You are tasked with building a harvest planning system for a greenhouse operation. This case study tests your ability to work with Python, PostgreSQL, Docker Compose, and understand a React frontend.

## Background
Our greenhouse farm operates 3 large greenhouses, each with a 50x8 grid layout (400 slots per greenhouse, 1200 total slots). The database contains information about:
- **Crop cycles**: Individual plantings with complete lifecycle data from seed to harvest
- **Locations**: Physical slots in the greenhouse where crops are grown (50x8 grid per greenhouse)
- **ML Harvest Predictions**: Machine learning predictions for harvest dates and yields in pounds

## Your Task
Build a simple API and web interface to help the operations team plan the next day's harvest.

## Getting Started

### 1. Start the Database
```bash
docker-compose up -d
```

This will start a PostgreSQL database on port 5432 with:
- Database: `greenhouse`
- Username: `postgres`
- Password: `postgres`

### 2. Database Schema
The database contains realistic greenhouse data with the following main tables:

**locations**: Physical greenhouse slots (1200 total across 3 greenhouses)
- `id`, `name`, `type`, `house_number`, `x_position`, `y_position`
- Each greenhouse has a 50x8 grid layout

**crop_cycles**: Plant lifecycle tracking (~1080 active crops, ~10% empty slots)
- `id`, `crop`, `sub_crop`, `module_id`, `slot_id`, `num_plants`
- `seed_timestamp`, `transplant_timestamp`, `scheduled_harvest_timestamp`
- `harvest_timestamp`, `harvest_weight_g`, `current_location`
- All crops have complete seed and transplant timestamps

**ml_harvest_predictions**: ML predictions for harvest planning
- `id`, `crop_cycle_id`, `predicted_harvest_date`, `predicted_yield_g`
- `days_since_transplant`, `confidence_score`, `model_version`, `features` (JSONB)
- Growth curve: Rapid growth until day 21, then plateaus

**Views Available:**
- `ready_for_harvest` - Crops ready for harvest with urgency levels and ML predictions
- `harvest_planning` - Harvest schedule with ML predictions and confidence scores
- `greenhouse_occupancy` - Occupancy statistics by greenhouse
- `greenhouse_layout` - Visual layout showing crop placement (L=Lettuce, S=Spinach, A=Arugula, K=Kale, space=Empty)
- `crop_growth_analysis` - Growth analysis comparing current vs optimal harvest timing
- `harvest_forecast` - Detailed harvest forecasts with ML predictions by timeframe

### 3. Explore the Data
Connect to the database and explore the existing data:
```bash
psql -h localhost -p 5432 -U postgres -d greenhouse
```

Try these queries to understand the data:
```sql
-- See what crops are ready for harvest
SELECT * FROM ready_for_harvest ORDER BY scheduled_harvest_timestamp LIMIT 10;

-- View harvest planning summary with ML predictions
SELECT * FROM harvest_planning;

-- Check greenhouse occupancy
SELECT * FROM greenhouse_occupancy;

-- View visual greenhouse layout
SELECT greenhouse_row, layout_columns_1_to_50 FROM greenhouse_layout ORDER BY house_number, row_number;

-- Check current crop cycles by type
SELECT crop, sub_crop, COUNT(*) as count 
FROM crop_cycles 
WHERE harvest_timestamp IS NULL 
GROUP BY crop, sub_crop
ORDER BY count DESC;

-- View ML predictions for next week
SELECT cc.crop, cc.sub_crop, mhp.predicted_harvest_date, mhp.predicted_yield_lbs, mhp.confidence_score
FROM crop_cycles cc
JOIN ml_harvest_predictions mhp ON cc.id = mhp.crop_cycle_id
WHERE mhp.predicted_harvest_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
ORDER BY mhp.predicted_harvest_date;
```

## Requirements

### Backend API (Python)
Create a Python API with the following endpoints:

1. **GET /api/crops/ready** - Return crops ready for harvest in the next 3 days
2. **GET /api/harvest/schedule** - Return harvest schedule for next 7 days with ML predictions
3. **PUT /api/crops/{crop_id}/harvest** - Update harvest timestamp and actual yield
4. **GET /api/crops/{crop_id}** - Get detailed information about a specific crop cycle including ML predictions
5. **GET /api/greenhouse/occupancy** - Return occupancy statistics for all 3 greenhouses

Requirements:
- Use FastAPI, Flask, or Django
- Include proper error handling
- Return JSON responses
- Include basic input validation

### Frontend Understanding
You'll be shown a React component that displays harvest data. Be prepared to:
- Explain how the component works
- Identify potential improvements
- Suggest how to integrate it with your API

## Evaluation Criteria

### Technical Skills
- **Python**: Clean, readable code with proper structure
- **Database**: Effective SQL queries and understanding of relational data
- **Docker**: Successful use of docker-compose for local development
- **API Design**: RESTful endpoints with appropriate HTTP methods

### Problem-Solving
- Understanding of the greenhouse domain and harvest planning needs
- Ability to work with existing database schema
- Practical approach to building the requested features

### Communication
- Clear explanations of technical decisions
- Ability to discuss trade-offs and alternative approaches
- Understanding of the React frontend concepts

## Sample Data
The database includes realistic greenhouse data:
- **1200 total slots** across 3 greenhouses (50x8 grid each)
- **~1068 active crop cycles** with ~10% empty slots for realistic occupancy
- **5000 completed crop cycles** with full harvest history (last 6 months)
- **4 crop types**: Lettuce, Spinach, Arugula, Kale with multiple varieties
- **Complete lifecycle data**: All crops have seed and transplant timestamps
- **ML predictions**: Harvest date and yield predictions in pounds with confidence scores
- **Historical data**: 5000 harvested crops with complete timestamps and yield data
- **Realistic timing**: Active crops scheduled for harvest over the next weeks

## Time Expectation
- **Setup and exploration**: 15-20 minutes
- **API development**: 45-60 minutes  
- **Frontend discussion**: 15-20 minutes

## Tips
- Start by exploring the database to understand the data structure
- The `ready_for_harvest` and `harvest_planning` views provide useful starting points
- Focus on core functionality first, then add features if time permits
- Ask questions if you need clarification on requirements

## Next Steps
1. Explore the database schema and sample data
2. Choose your Python framework and set up the project
3. Implement the required API endpoints
4. Test your endpoints with sample requests
5. Be ready to discuss the React frontend component

Good luck! 🌱