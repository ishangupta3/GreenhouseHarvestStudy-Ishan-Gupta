from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime

# Base schemas
class LocationBase(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    house_number: Optional[int] = None
    x_position: Optional[int] = None
    y_position: Optional[int] = None

class Location(LocationBase):
    id: int
    
    class Config:
        from_attributes = True

class CropCycleBase(BaseModel):
    crop: Optional[str] = None
    sub_crop: Optional[str] = None
    num_plants: Optional[int] = None
    scheduled_harvest_timestamp: Optional[datetime] = None
    harvest_timestamp: Optional[datetime] = None
    harvest_weight_g: Optional[float] = None

class CropCycle(CropCycleBase):
    id: int
    current_location: Optional[int] = None
    
    class Config:
        from_attributes = True

class MLPredictionBase(BaseModel):
    predicted_harvest_date: date
    predicted_yield_g: float
    confidence_score: Optional[float] = None

class MLPrediction(MLPredictionBase):
    id: int
    crop_cycle_id: int
    
    class Config:
        from_attributes = True

# Harvest scheduling schemas
class HarvestScheduleRequest(BaseModel):
    target_date: date
    crop_type: str
    target_yield_g: float = 4000.0
    min_confidence: float = 0.8

class HarvestScheduleResponse(BaseModel):
    target_date: date
    crop_type: str
    target_yield_g: float
    selected_crops: List[dict]
    total_predicted_yield_g: float
    confidence_score: float

class WeeklyHarvestPlan(BaseModel):
    week_start: date
    week_end: date
    daily_schedules: List[HarvestScheduleResponse]

# API response schemas
class CropAvailability(BaseModel):
    crop: str
    available_crops: int
    avg_yield_g: float
    avg_confidence: float
    max_yield_g: float

class DailyHarvestSummary(BaseModel):
    date: date
    crop_availabilities: List[CropAvailability]
    total_available_yield_g: float 