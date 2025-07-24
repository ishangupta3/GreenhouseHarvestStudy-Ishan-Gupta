from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from fastapi.requests import Request
import psycopg2
import json
import os
from datetime import date
from typing import Dict, List, Optional
from pydantic import BaseModel

app = FastAPI(
    title="Greenhouse Harvest Planning System",
    description="API for scheduling harvests using ML predictions",
    version="1.0.0"
)

# Mount static files and templates only if directories exist
if os.path.exists("static"):
    app.mount("/static", StaticFiles(directory="static"), name="static")

if os.path.exists("templates"):
    templates = Jinja2Templates(directory="templates")
else:
    templates = None

def get_db_connection():
    """Create database connection to PostgreSQL"""
    try:
        return psycopg2.connect(
            host="postgres",  # Use service name from docker-compose
            port="5432",
            database="greenhouse",
            user="postgres",
            password="postgres"
        )
    except Exception as e:
        print(f"Database connection error: {e}")
        raise

def get_crops_for_date(target_date: str) -> Dict:
    """
    Get available crops with ML predictions for a specific date.
    
    This function retrieves crops that are:
    - Available for harvest on the target date (ML predictions)
    - Not yet harvested (harvest_timestamp IS NULL)
    - Have high confidence ML predictions (>= 0.8)
    - Are one of the target crop types (Lettuce, Arugula, Spinach, Kale)
    - Not already in the user's harvest plan for that date
    
    Args:
        target_date: Date in YYYY-MM-DD format
    
    Returns:
        Dict with crops organized by type and summary statistics
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Query crops with ML predictions, filtering out already planned crops
        query = """
        SELECT 
            cc.id,
            cc.crop,
            cc.sub_crop,
            cc.num_plants,
            mhp.predicted_yield_g,
            mhp.confidence_score,
            l.house_number,
            l.x_position,
            l.y_position
        FROM crop_cycles cc
        JOIN ml_harvest_predictions mhp ON cc.id = mhp.crop_cycle_id
        JOIN locations l ON cc.current_location = l.id
        WHERE mhp.predicted_harvest_date = %s
          AND cc.harvest_timestamp IS NULL
          AND mhp.confidence_score >= 0.8
          AND cc.crop IN ('LETTUCE', 'ARUGULA', 'SPINACH', 'KALE')
          AND cc.id NOT IN (
              SELECT crop_cycle_id 
              FROM harvest_plans 
              WHERE target_date = %s
          )
        ORDER BY cc.crop, mhp.confidence_score DESC, mhp.predicted_yield_g DESC
        """
        
        cursor.execute(query, (target_date, target_date))
        results = cursor.fetchall()
        
        # Process results into organized structure
        crops_by_type = {}
        total_crops = 0
        total_yield_g = 0
        
        for row in results:
            crop_type = row[1]
            if crop_type not in crops_by_type:
                crops_by_type[crop_type] = []
            
            crop_data = {
                "id": row[0],
                "sub_crop": row[2],
                "num_plants": row[3],
                "predicted_yield_g": float(row[4]),
                "confidence_score": float(row[5]),
                "house_number": row[6],
                "x_position": row[7],
                "y_position": row[8]
            }
            
            crops_by_type[crop_type].append(crop_data)
            total_crops += 1
            total_yield_g += crop_data["predicted_yield_g"]
        
        cursor.close()
        conn.close()
        
        return {
            "date": target_date,
            "crops": crops_by_type,
            "summary": {
                "total_available_crops": total_crops,
                "total_predicted_yield_g": total_yield_g,
                "total_predicted_yield_kg": round(total_yield_g / 1000, 2)
            }
        }
        
    except Exception as e:
        print(f"Error fetching crops: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    """Main web interface for harvest planning"""
    if templates:
        return templates.TemplateResponse("index.html", {"request": request})
    else:
        return HTMLResponse("""
        <html>
            <head><title>Greenhouse Harvest Planning</title></head>
            <body>
                <h1>🌱 Greenhouse Harvest Planning System</h1>
                <p>API is running! Use the following endpoints:</p>
                <ul>
                    <li><a href="/api/health">Health Check</a></li>
                    <li><a href="/api/crops/2025-07-21">Get Crops for July 21, 2025</a></li>
                    <li><a href="/docs">API Documentation</a></li>
                </ul>
            </body>
        </html>
        """)

@app.get("/api/crops/{target_date}")
async def get_available_crops(target_date: str):
    """
    Get available crops with ML predictions for a specific date
    
    Args:
        target_date: Date in YYYY-MM-DD format (e.g., 2025-07-21)
    
    Returns:
        JSON with available crops organized by type and summary statistics
    """
    try:
        # Validate date format
        date.fromisoformat(target_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    
    return get_crops_for_date(target_date)

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
        cursor.close()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}

# Pydantic models for harvest planning API
class HarvestPlanItem(BaseModel):
    """
    Data model for individual crops in a harvest plan.
    Used for both adding crops to plans and retrieving plan data.
    """
    crop_cycle_id: int          # Reference to the crop_cycles table
    crop_type: str              # LETTUCE, ARUGULA, SPINACH, KALE
    sub_crop: str               # Specific variety (e.g., "Butter Crunch")
    planned_yield_g: float      # Expected yield in grams (from ML predictions)
    confidence_score: float     # ML model confidence (0.0-1.0)
    house_number: int           # Greenhouse house number (1-3)
    location_x: int             # X position in greenhouse grid
    location_y: int             # Y position in greenhouse grid

class HarvestPlanResponse(BaseModel):
    """
    Response model for harvest plan data including summary statistics.
    """
    date: str                   # Target harvest date (YYYY-MM-DD)
    items: List[HarvestPlanItem] # List of planned crops
    summary: Dict               # Summary with totals and target progress

# Harvest Planning API Endpoints
@app.post("/api/plans/{target_date}/add")
async def add_to_harvest_plan(target_date: str, item: HarvestPlanItem):
    """
    Add a crop to the harvest plan for a specific date.
    
    This endpoint allows users to add individual crops to their harvest plan.
    The system validates that the crop isn't already planned for that date
    and stores the ML prediction data for planning purposes.
    
    Args:
        target_date: Harvest date in YYYY-MM-DD format
        item: HarvestPlanItem with crop details and ML predictions
    
    Returns:
        JSON with success message and plan ID
    
    Raises:
        400: Invalid date format or crop already in plan
        500: Database error
    """
    try:
        # Validate date format
        date.fromisoformat(target_date)
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Prevent duplicate crops in the same plan
        cursor.execute("""
            SELECT id FROM harvest_plans 
            WHERE target_date = %s AND crop_cycle_id = %s
        """, (target_date, item.crop_cycle_id))
        
        if cursor.fetchone():
            cursor.close()
            conn.close()
            raise HTTPException(status_code=400, detail="Crop already in plan for this date")
        
        # Store crop in harvest plan with ML prediction data
        cursor.execute("""
            INSERT INTO harvest_plans 
            (target_date, crop_cycle_id, crop_type, sub_crop, planned_yield_g, 
             confidence_score, house_number, location_x, location_y)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            target_date, item.crop_cycle_id, item.crop_type, item.sub_crop,
            int(item.planned_yield_g), item.confidence_score, item.house_number,
            item.location_x, item.location_y
        ))
        
        plan_id = cursor.fetchone()[0]
        conn.commit()
        cursor.close()
        conn.close()
        
        return {"message": "Crop added to harvest plan", "plan_id": plan_id}
        
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        print(f"Error adding to harvest plan: {e}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/api/plans/{target_date}")
async def get_harvest_plan(target_date: str):
    """
    Get the current harvest plan for a specific date with target progress tracking.
    
    This endpoint retrieves all planned crops for a date and calculates progress
    toward the 4kg daily target for each crop type. The response includes both
    individual crop details and summary statistics for planning purposes.
    
    Args:
        target_date: Harvest date in YYYY-MM-DD format
    
    Returns:
        JSON with plan items and summary including:
        - Total items and yield
        - Progress toward 4kg targets per crop type
        - Individual crop details with ML predictions
    
    Raises:
        400: Invalid date format
        500: Database error
    """
    try:
        # Validate date format
        date.fromisoformat(target_date)
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Retrieve all planned crops for the target date
        cursor.execute("""
            SELECT id, crop_cycle_id, crop_type, sub_crop, planned_yield_g,
                   confidence_score, house_number, location_x, location_y
            FROM harvest_plans 
            WHERE target_date = %s
            ORDER BY crop_type, planned_yield_g DESC
        """, (target_date,))
        
        results = cursor.fetchall()
        
        items = []
        total_yield_g = 0
        crops_by_type = {}
        
        # Process each planned crop
        for row in results:
            item = HarvestPlanItem(
                crop_cycle_id=row[1],
                crop_type=row[2],
                sub_crop=row[3],
                planned_yield_g=row[4],
                confidence_score=float(row[5]),
                house_number=row[6],
                location_x=row[7],
                location_y=row[8]
            )
            items.append(item)
            total_yield_g += row[4]
            
            # Aggregate data by crop type for target progress calculation
            if row[2] not in crops_by_type:
                crops_by_type[row[2]] = {"count": 0, "total_yield_g": 0}
            crops_by_type[row[2]]["count"] += 1
            crops_by_type[row[2]]["total_yield_g"] += row[4]
        
        cursor.close()
        conn.close()
        
        # Calculate progress toward 4kg daily targets for each crop type
        target_progress = {}
        for crop_type, data in crops_by_type.items():
            target_g = 4000  # 4kg target per crop type per day
            progress_percent = min(100, (data["total_yield_g"] / target_g) * 100)
            target_progress[crop_type] = {
                "current_g": data["total_yield_g"],
                "current_kg": round(data["total_yield_g"] / 1000, 2),
                "target_g": target_g,
                "target_kg": 4.0,
                "progress_percent": round(progress_percent, 1),
                "count": data["count"]
            }
        
        # Compile summary statistics
        summary = {
            "total_items": len(items),
            "total_yield_g": total_yield_g,
            "total_yield_kg": round(total_yield_g / 1000, 2),
            "target_progress": target_progress
        }
        
        return {
            "date": target_date,
            "items": items,
            "summary": summary
        }
        
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        print(f"Error getting harvest plan: {e}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.delete("/api/plans/{target_date}/remove/{crop_cycle_id}")
async def remove_from_harvest_plan(target_date: str, crop_cycle_id: int):
    """
    Remove a crop from the harvest plan for a specific date.
    
    This endpoint allows users to remove individual crops from their harvest plan.
    The system validates that the crop exists in the plan before removal.
    
    Args:
        target_date: Harvest date in YYYY-MM-DD format
        crop_cycle_id: ID of the crop to remove from the plan
    
    Returns:
        JSON with success message
    
    Raises:
        400: Invalid date format
        404: Crop not found in plan for this date
        500: Database error
    """
    try:
        # Validate date format
        date.fromisoformat(target_date)
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Remove the crop from the harvest plan
        cursor.execute("""
            DELETE FROM harvest_plans 
            WHERE target_date = %s AND crop_cycle_id = %s
            RETURNING id
        """, (target_date, crop_cycle_id))
        
        deleted_row = cursor.fetchone()
        
        if not deleted_row:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Crop not found in plan for this date")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return {"message": "Crop removed from harvest plan"}
        
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    except Exception as e:
        print(f"Error removing from harvest plan: {e}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 