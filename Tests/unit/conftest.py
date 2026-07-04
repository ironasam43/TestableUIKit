"""
conftest.py for Tests/unit/

For L1 tests of pure helpers. No HTTP connection or DemoApp startup required.
Overrides the autouse reset_state fixture from Tests/conftest.py (which calls HTTP)
with a no-op to prevent IPC connection errors.
"""

import pytest


@pytest.fixture(autouse=True)
def reset_state():
    """No-op override: pure unit tests do not require HTTP connections."""
    yield
