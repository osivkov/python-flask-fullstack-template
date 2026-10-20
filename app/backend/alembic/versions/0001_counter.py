"""Create and seed the example counter."""

import sqlalchemy as sa
from alembic import op

revision = "0001_counter"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    counter = op.create_table(
        "counter",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("value", sa.BigInteger(), nullable=False),
    )
    op.bulk_insert(counter, [{"id": 1, "value": 0}])


def downgrade():
    op.drop_table("counter")
