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
    """Get available crops with ML predictions for a specific date"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
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
        ORDER BY cc.crop, mhp.confidence_score DESC, mhp.predicted_yield_g DESC
        """
        
        cursor.execute(query, (target_date,))
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 