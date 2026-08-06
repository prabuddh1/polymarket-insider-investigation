from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.engine import Connection, Engine

from src.common.config import settings


engine: Engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=5,
    future=True,
)


def transaction() -> Iterator[Connection]:
    with engine.begin() as connection:
        yield connection
