# Greenhouse Harvest Planning Case Study

## Overview

It's mid-July 2025 at Hippo Harvest, and it's hot.  There's lots of daylight, so our leafy greens are growing really fast, and we need to harvest them at the optimal point in their growth cycle.  Our robots write a bunch of data about the plant's growth cycle to the database, but we need better tooling for scheduling when to harvest the crops in greenhouses.

## Your Task

You are tasked with building a simple harvest planning system for a greenhouse operation, with a REST API layer written in Python and frontend web app. This case study tests your ability to work with Python, PostgreSQL, Docker Compose and web apps.  A starter git repo is located here:

This includes building a simple API and web interface to help the operations team plan harvests. As part of this project, you should:

* Create a Python REST API to serve the data to downstream services. We need intuitive REST APIs at our farm since multiple downstream services consume this data.  

* Make any database changes you'd need to improve the data model. You can add tables or views if needed, just make sure to keep track of the schema changes you make with migrations.  

* Create a simple, but intuitive web app so that non-technical users can schedule harvests for the the end of July 2025 (weeks starting on July 21st and 28th).  No need to tinker with CSS unless you enjoy it.
  * Through the web app, you should build a bare-bone UI that can help Hippo Harvest’s planners make informed about which models to harvest  
  * For the mock mini-farm, planners should target a harvest of 4 kgs of greens, five days a week, for each crop: lettuce, arugula, spinach, and kale.  It may not be possible each day, but the planner should strive for consistent production levels.

* Ensure the developer experience for adding new features or making changes is simple and well-documented

[A starter git repo for this project is located at this link](https://github.com/Hippo-Harvest/fullstack-case-study-2025).  You need a GitHub login for access.

We expect that you'll use AI coding assistants to help build this. That's great — and you'll need to be able to explain all the code that the AI assistant generates. In the interview, you'll be asked to present your solution, and then be asked detailed questions about the design choices, frameworks, and coding patterns you implemented.

This case study is very open-ended. If something's unclear, feel free to document your assumptions and move forward. Our engineers at Hippo Harvest to work autonomously, and the case is designed to reflect that. We expect this case study to take no more than half a day's work.

## Background

The simplified mock farm in this test case operates 3 large greenhouses, each with a 50x8 grid layout (400 slots per greenhouse, 1200 total slots). Each slot can be occupied by a crop.  The database contains information about:

* **Crop cycles**: Individual plantings with complete lifecycle data from seed to harvest  
* **Locations**: Physical slots in the greenhouse where crops are grown (50x8 grid per greenhouse)  
* **ML Harvest Predictions**: Machine learning predictions for harvest dates and yields in grams

## Getting Started

### 1\. Clone the project repo

```shell
git clone https://github.com/Hippo-Harvest/fullstack-case-study-2025.gitcd fullstack-case-study-2025
```

### 2\. Start the Database

```shell
docker-compose up -d
```

This will start a PostgreSQL database on port 5432 with:

* Database: `greenhouse`  
* Username: `postgres`  
* Password: `postgres`

### 3\. Database Schema

The database contains realistic greenhouse data with the following main tables:

**locations**: Physical greenhouse slots (1200 total across 3 greenhouses)

* `id`, `name`, `type`, `house_number`, `x_position`, `y_position`  
* Each greenhouse has a 50x8 grid layout

**crop\_cycles**: Plant lifecycle tracking (\~1080 active crops, \~10% empty slots)

* `id`, `crop`, `sub_crop`, `module_id`, `slot_id`, `num_plants`  
* `seed_timestamp`, `transplant_timestamp`, `scheduled_harvest_timestamp`  
* `harvest_timestamp`, `harvest_weight_g`, `current_location`  
* All crops have complete seed and transplant timestamps since they have been seeded and transplanted to a slot in the farm.

**ml\_harvest\_predictions**: ML predictions for harvest planning

* `id`, `crop_cycle_id`, `predicted_harvest_date`, `predicted_yield_g`  
* `days_since_transplant`, `confidence_score`, `model_version`, `features` (JSONB)  
* Given a day you'd harvest, these models generate the yield you'd get for a given crop.

**Views Available:**

* `ready_for_harvest` \- Crops ready for harvest with urgency levels and ML predictions  
* `harvest_planning` \- Harvest schedule with ML predictions and confidence scores  
* `greenhouse_occupancy` \- Occupancy statistics by greenhouse  
* `greenhouse_layout` \- Visual layout showing crop placement (L=Lettuce, S=Spinach, A=Arugula, K=Kale, space=Empty)

### 4\. Explore the Data

Connect to the database and explore the existing data:

```shell
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
SELECT cc.crop, cc.sub_crop, mhp.predicted_harvest_date, mhp.predicted_yield_g, mhp.confidence_score
FROM crop_cycles cc
JOIN ml_harvest_predictions mhp ON cc.id = mhp.crop_cycle_id
WHERE mhp.predicted_harvest_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
ORDER BY mhp.predicted_harvest_date;
```

## Sample Data

The database includes realistic greenhouse data:

* **1200 total slots** across 3 greenhouses (50x8 grid each)  
* **\~1068 active crop cycles** with \~10% empty slots for realistic occupancy  
* **5000 completed crop cycles** with full harvest history (last 6 months)  
* **4 crop types**: Lettuce, Spinach, Arugula, Kale with multiple varieties  
* **Complete lifecycle data**: All crops have seed and transplant timestamps  
* **ML predictions**: Harvest date and yield predictions in pounds with confidence scores  
* **Historical data**: 5000 harvested crops with complete timestamps and yield data  
* **Realistic timing**: Active crops scheduled for harvest over the coming weeks

## Sharing your project

When you're ready to share your completed project with the Hippo Harvest team:

1. **Clone this repository** to your own GitHub account:

```shell
git clone https://github.com/Hippo-Harvest/fullstack-case-study-2025.git
cd fullstack-case-study-2025
```

2. **Create a new remote repository** on GitHub, GitLab, or your preferred git hosting service  

3. **Update the remote origin** to point to your new repository:

```shell
git remote set-url origin https://github.com/your-username/your-new-repo-name.git
```

4. **Push your changes** to your new repository:

```shell
git push -u origin main
```

5. **Share the repository** with the following team members at Hippo Harvest:  

* Kevin ([https://github.com/kevin-presalytics](https://github.com/kevin-presalytics))  
* Gil ([https://github.com/egiljoneshippo](https://github.com/egiljoneshippo))

**Note**: Since you only have read access to the original repository, you'll need to create your own copy to share your work.

git clone <https://github.com/Hippo-Harvest/fullstack-case-study-2025.gitMake> sure your repository is private and grant access to the Hippo Harvest team members listed.

## Tips

* Start by exploring the database to understand the data structure  
* Pick common Python and JavaScript frameworks to work with so that code is easy for everyone (including AI tools) to understand  
* Once you've designed the system, update `docker-compose.yml` to bring up the whole system with a single command.  
* Focus on core functionality first, then add features if time permits

## Good luck\

🌱 We're excited to see what you build\!  
