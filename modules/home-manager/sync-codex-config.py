import os
from pathlib import Path
import sys
import tempfile
from collections.abc import MutableMapping

import tomlkit


def merge(target, defaults):
    for key, value in defaults.items():
        if isinstance(value, MutableMapping) and isinstance(target.get(key), MutableMapping):
            merge(target[key], value)
        else:
            target[key] = value


def sync(defaults_path, runtime_path):
    defaults = tomlkit.parse(defaults_path.read_text())
    current = tomlkit.parse(runtime_path.read_text()) if runtime_path.exists() else tomlkit.document()
    merge(current, defaults)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    # Replace the link itself during migration; never write through it into Git.
    fd, temporary = tempfile.mkstemp(dir=runtime_path.parent, prefix=".config-")
    try:
        with os.fdopen(fd, "w") as output:
            output.write(tomlkit.dumps(current))
        os.replace(temporary, runtime_path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    sync(Path(sys.argv[1]), Path(sys.argv[2]))
