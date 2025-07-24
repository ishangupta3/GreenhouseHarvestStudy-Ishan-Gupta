from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from datetime import date, timedelta
from typing import List, Dict, Optional
from .models import CropCycle, MLHarvestPrediction, Location
from .schemas import HarvestScheduleResponse, CropAvailability

class HarvestPlanner:
    def __init__(self, db: Session):
        self.db = db
    
    def get_available_crops_for_date(self, target_date: date, crop_type: str = None) -> List[Dict]:
        """
        Get all available crops with ML predictions for a specific date
        """
        query = self.db.query(
            CropCycle.id,
            CropCycle.crop,
            CropCycle.sub_crop,
            CropCycle.num_plants,
            MLHarvestPrediction.predicted_yield_g,
            MLHarvestPrediction.confidence_score,
            Location.house_number,
            Location.x_position,
            Location.y_position
        ).join(
            MLHarvestPrediction, 
            and_(
                CropCycle.id == MLHarvestPrediction.crop_cycle_id,
                MLHarvestPrediction.predicted_harvest_date == target_date
            )
        ).join(
            Location, CropCycle.current_location == Location.id
        ).filter(
            CropCycle.harvest_timestamp.is_(None),
            CropCycle.dispose == False
        )
        
        if crop_type:
            query = query.filter(CropCycle.crop == crop_type.upper())
        
        results = query.all()
        
        return [
            {
                "id": r.id,
                "crop": r.crop,
                "sub_crop": r.sub_crop,
                "num_plants": r.num_plants,
                "predicted_yield_g": r.predicted_yield_g,
                "confidence_score": r.confidence_score,
                "house_number": r.house_number,
                "x_position": r.x_position,
                "y_position": r.y_position
            }
            for r in results
        ]
    
    def schedule_harvest_for_date(
        self, 
        target_date: date, 
        crop_type: str, 
        target_yield_g: float = 4000.0,
        min_confidence: float = 0.8
    ) -> HarvestScheduleResponse:
        """
        Schedule optimal harvest for a specific date and crop type using ML predictions
        """
        available_crops = self.get_available_crops_for_date(target_date, crop_type)
        
        # Filter by confidence score
        high_confidence_crops = [
            crop for crop in available_crops 
            if crop["confidence_score"] >= min_confidence
        ]
        
        if not high_confidence_crops:
            return HarvestScheduleResponse(
                target_date=target_date,
                crop_type=crop_type,
                target_yield_g=target_yield_g,
                selected_crops=[],
                total_predicted_yield_g=0.0,
                confidence_score=0.0
            )
        
        # Strategy 1: Find single large crop
        large_crops = [
            crop for crop in high_confidence_crops 
            if crop["predicted_yield_g"] >= target_yield_g
        ]
        
        if large_crops:
            # Select the crop with highest confidence and yield
            best_crop = max(large_crops, key=lambda x: (x["confidence_score"], x["predicted_yield_g"]))
            
            return HarvestScheduleResponse(
                target_date=target_date,
                crop_type=crop_type,
                target_yield_g=target_yield_g,
                selected_crops=[best_crop],
                total_predicted_yield_g=best_crop["predicted_yield_g"],
                confidence_score=best_crop["confidence_score"]
            )
        
        # Strategy 2: Combine multiple smaller crops
        selected_crops = []
        total_yield = 0.0
        total_confidence = 0.0
        
        # Sort by confidence score (highest first)
        sorted_crops = sorted(high_confidence_crops, key=lambda x: x["confidence_score"], reverse=True)
        
        for crop in sorted_crops:
            if total_yield < target_yield_g:
                selected_crops.append(crop)
                total_yield += crop["predicted_yield_g"]
                total_confidence += crop["confidence_score"]
            else:
                break
        
        avg_confidence = total_confidence / len(selected_crops) if selected_crops else 0.0
        
        return HarvestScheduleResponse(
            target_date=target_date,
            crop_type=crop_type,
            target_yield_g=target_yield_g,
            selected_crops=selected_crops,
            total_predicted_yield_g=total_yield,
            confidence_score=avg_confidence
        )
    
    def get_weekly_harvest_plan(
        self, 
        week_start: date,
        crop_types: List[str] = ["LETTUCE", "ARUGULA", "SPINACH", "KALE"]
    ) -> List[HarvestScheduleResponse]:
        """
        Generate harvest plan for a week (Monday-Friday only)
        """
        schedules = []
        
        # Generate dates for the week (Monday = 0, Friday = 4)
        current_date = week_start
        for i in range(5):  # Monday to Friday only
            if current_date.weekday() < 5:  # Skip weekends
                for crop_type in crop_types:
                    schedule = self.schedule_harvest_for_date(
                        target_date=current_date,
                        crop_type=crop_type,
                        target_yield_g=4000.0
                    )
                    schedules.append(schedule)
            current_date += timedelta(days=1)
        
        return schedules
    
    def get_crop_availability_summary(self, target_date: date) -> List[CropAvailability]:
        """
        Get summary of available crops for a specific date
        """
        crop_types = ["LETTUCE", "ARUGULA", "SPINACH", "KALE"]
        availabilities = []
        
        for crop_type in crop_types:
            available_crops = self.get_available_crops_for_date(target_date, crop_type)
            
            if available_crops:
                avg_yield = sum(c["predicted_yield_g"] for c in available_crops) / len(available_crops)
                avg_confidence = sum(c["confidence_score"] for c in available_crops) / len(available_crops)
                max_yield = max(c["predicted_yield_g"] for c in available_crops)
                
                availabilities.append(CropAvailability(
                    crop=crop_type,
                    available_crops=len(available_crops),
                    avg_yield_g=avg_yield,
                    avg_confidence=avg_confidence,
                    max_yield_g=max_yield
                ))
        
        return availabilities 