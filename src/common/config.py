from datetime import datetime
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str

    gamma_api_base: str
    data_api_base: str
    clob_api_base: str

    analysis_start: datetime
    analysis_end: datetime

    http_timeout_seconds: int = 30
    http_max_retries: int = 5
    http_concurrency: int = 4

    raw_data_dir: Path = Path("data/raw")
    artifact_dir: Path = Path("artifacts")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


settings = Settings()
