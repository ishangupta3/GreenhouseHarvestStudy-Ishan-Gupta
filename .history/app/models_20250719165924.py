from sqlalchemy import Column, Integer, String, DateTime, Float, Boolean, Text, ForeignKey, Date
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import JSONB
from .database import Base

class Location(Base):
    __tablename__ = "locations"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    type = Column(String)
    house_number = Column(Integer)
    x_position = Column(Integer)
    y_position = Column(Integer)
    
    # Relationship
    crop_cycles = relationship("CropCycle", back_populates="location")

class CropCycle(Base):
    __tablename__ = "crop_cycles"
    
    id = Column(Integer, primary_key=True, index=True)
    seed_id = Column(String)
    crop = Column(String, index=True)
    seed_type = Column(String)
    sub_crop = Column(String)
    module_id = Column(String, index=True)
    germination_id = Column(String)
    num_plants = Column(Integer)
    substrate = Column(String)
    slot_id = Column(String, index=True)
    x = Column(Float)
    y = Column(Float)
    dock_id = Column(String)
    seed_timestamp = Column(DateTime)
    transplant_timestamp = Column(DateTime, index=True)
    harvest_timestamp = Column(DateTime, index=True)
    clean_timestamp = Column(DateTime)
    scheduled_seed_timestamp = Column(DateTime)
    scheduled_transplant_timestamp = Column(DateTime)
    scheduled_harvest_timestamp = Column(DateTime, index=True)
    fertigation_profile = Column(String)
    notes = Column(Text)
    dispose = Column(Boolean, default=False)
    inputs = Column(Text)
    harvest_weight_g = Column(Float)
    cut_height_offset = Column(Float, default=0)
    root = Column(Integer)
    parent = Column(Integer)
    child = Column(Integer)
    cut = Column(Integer, default=0)
    harvest_bags = Column(JSONB)
    data = Column(JSONB)
    harvest_order = Column(Integer)
    sku = Column(String)
    mix = Column(Boolean)
    tags = Column(JSONB)
    is_organic = Column(Boolean)
    sku_group = Column(Integer)
    harvest_notes = Column(Text)
    dispose_reasons = Column(JSONB)
    completed_timestamp = Column(DateTime)
    current_location = Column(Integer, ForeignKey("locations.id"), index=True)
    is_experiment = Column(Boolean)
    
    # Relationships
    location = relationship("Location", back_populates="crop_cycles")
    ml_predictions = relationship("MLHarvestPrediction", back_populates="crop_cycle")

class MLHarvestPrediction(Base):
    __tablename__ = "ml_harvest_predictions"
    
    id = Column(Integer, primary_key=True, index=True)
    crop_cycle_id = Column(Integer, ForeignKey("crop_cycles.id"), index=True)
    predicted_harvest_date = Column(Date, index=True)
    predicted_yield_g = Column(Float)
    days_since_transplant = Column(Integer)
    confidence_score = Column(Float)
    model_version = Column(String, default="growth_predictor_v3.2")
    prediction_timestamp = Column(DateTime)
    features = Column(JSONB)
    created_at = Column(DateTime)
    updated_at = Column(DateTime)
    
    # Relationship
    crop_cycle = relationship("CropCycle", back_populates="ml_predictions") 