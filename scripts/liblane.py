import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import steps  # noqa: E402,F401
from librelane.__main__ import cli  # noqa: E402

if __name__ == "__main__":
    cli()
