from typing import List
from pydantic_settings import BaseSettings


class Settings(BaseSettings):

    APP_NAME: str = "MeterVision Backend"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"

    DEBUG: bool = True

    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str
    SUPABASE_ANON_KEY: str

    STORAGE_BUCKET: str = "meter-images"

    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"

    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    
    OCR_LOW_CONFIDENCE: float = 0.70

    
    BLUR_THRESHOLD: float = 100.0

    
    ANOMALY_MULTIPLIER: float = 3.0

    
    MAX_IMAGE_SIZE_MB: int = 10

    ALLOWED_IMAGE_TYPES: List[str] = [
        "image/jpeg",
        "image/jpg",
        "image/png"
    ]

    
    MAX_SYNC_RETRIES: int = 5

    

    
    FCM_SERVER_KEY: str = ""

    
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8501"
    ]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()