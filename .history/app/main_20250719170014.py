from fastapi import FastAPI, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from fastapi.requests import Request
from sqlalchemy.orm import Session
from datetime import date, timedelta
from typing import List
import os

from .database import get_db
from .harvest_planner import HarvestPlanner
from .schemas import (
    HarvestScheduleRequest, 
    HarvestScheduleResponse, 
    CropAvailability,
    WeeklyHarvestPlan
)

app = FastAPI(
    title="Greenhouse Harvest Planning System",
    description="API for scheduling harvests using ML predictions",
    version="1.0.0"
)

# Mount static files and templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    """Main web interface for harvest planning"""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/api/crops/active")
async def get_active_crops(db: Session = Depends(get_db)):
    """Get all active crops"""
    planner = HarvestPlanner(db)
    # Get today's date for demonstration
    today = date(2025, 7, 21)  # Target week start
    return planner.get_crop_availability_summary(today)

@app.get("/api/crops/{crop_type}")
async def get_crops_by_type(crop_type: str, db: Session = Depends(get_db)):
    """Get crops by type"""
    planner = HarvestPlanner(db)
    today = date(2025, 7, 21)
    return planner.get_available_crops_for_date(today, crop_type.upper())

@app.get("/api/predictions/{target_date}")
async def get_predictions_for_date(target_date: date, db: Session = Depends(get_db)):
    """Get ML predictions for a specific date"""
    planner = HarvestPlanner(db)
    return planner.get_crop_availability_summary(target_date)

@app.post("/api/schedule/harvest", response_model=HarvestScheduleResponse)
async def schedule_harvest(
    request: HarvestScheduleRequest,
    db: Session = Depends(get_db)
):
    """Schedule a harvest for a specific date and crop type"""
    planner = HarvestPlanner(db)
    return planner.schedule_harvest_for_date(
        target_date=request.target_date,
        crop_type=request.crop_type,
        target_yield_g=request.target_yield_g,
        min_confidence=request.min_confidence
    )

@app.get("/api/schedule/weekly", response_model=List[HarvestScheduleResponse])
async def get_weekly_schedule(
    week_start: date = date(2025, 7, 21),
    db: Session = Depends(get_db)
):
    """Get weekly harvest schedule (Monday-Friday)"""
    planner = HarvestPlanner(db)
    return planner.get_weekly_harvest_plan(week_start)

@app.get("/api/schedule/target-weeks")
async def get_target_weeks_schedule(db: Session = Depends(get_db)):
    """Get harvest schedule for target weeks (July 21-28, 2025)"""
    planner = HarvestPlanner(db)
    
    # Week 1: July 21-25 (Monday-Friday)
    week1_start = date(2025, 7, 21)
    week1_schedule = planner.get_weekly_harvest_plan(week1_start)
    
    # Week 2: July 28 (Monday only)
    week2_start = date(2025, 7, 28)
    week2_schedule = planner.get_weekly_harvest_plan(week2_start)
    
    return {
        "week1": {
            "start_date": week1_start,
            "end_date": date(2025, 7, 25),
            "schedules": week1_schedule
        },
        "week2": {
            "start_date": week2_start,
            "end_date": date(2025, 7, 28),
            "schedules": week2_schedule
        }
    }

@app.get("/api/occupancy")
async def get_greenhouse_occupancy(db: Session = Depends(get_db)):
    """Get greenhouse occupancy statistics"""
    # This would query the greenhouse_occupancy view
    # For now, return a placeholder
    return {
        "house_1": {"total_slots": 400, "occupied": 354, "occupancy_percent": 88.5},
        "house_2": {"total_slots": 400, "occupied": 345, "occupancy_percent": 86.25},
        "house_3": {"total_slots": 400, "occupied": 356, "occupancy_percent": 89.0}
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 