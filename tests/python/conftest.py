import importlib.util
import sys
from pathlib import Path

SKILLS_ROOT = Path(__file__).parent.parent.parent / "skills"


def load_script(rel_path: str):
    path = SKILLS_ROOT / rel_path
    spec = importlib.util.spec_from_file_location(path.stem, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[path.stem] = mod
    spec.loader.exec_module(mod)
    return mod
