"""${message}"""

import sqlalchemy as sa  # noqa: F401 - generated revisions may not need SQL types
from alembic import op  # noqa: F401 - generated revisions may be empty
${imports if imports else ""}

revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade():
    ${upgrades if upgrades else "pass"}


def downgrade():
    ${downgrades if downgrades else "pass"}
