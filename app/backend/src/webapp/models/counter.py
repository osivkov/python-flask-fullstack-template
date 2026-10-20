from sqlalchemy import BigInteger
from sqlalchemy.orm import Mapped, mapped_column

from webapp.extensions import db


class Counter(db.Model):
    __tablename__ = "counter"

    id: Mapped[int] = mapped_column(primary_key=True)
    value: Mapped[int] = mapped_column(BigInteger, default=0)
