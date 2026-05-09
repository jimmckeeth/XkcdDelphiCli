# Custom Pascal/Delphi Chunker for cocoindex-code

This guide explains how to use a custom Tree-Sitter Pascal grammar (like [jimmckeeth/tree-sitter-pascal](https://github.com/jimmckeeth/tree-sitter-pascal)) with `cocoindex-code` (`ccc`).

Because `cocoindex-code` uses a pre-compiled Rust core for its built-in `RecursiveSplitter`, you cannot swap internal grammars via simple config. Instead, you can use a **Custom Python Chunker** to provide syntax-aware chunking using your own compiled `.dll` or `.so`.

## 1. Prerequisites

### Python Environment
Ensure the `tree-sitter` Python package is installed in the same environment as `cocoindex-code`:
```powershell
pip install tree-sitter
```

### Compiled Grammar
You need the compiled Tree-Sitter Pascal library (`.dll` for Windows, `.so` for Linux, `.dylib` for macOS).
- **Architecture:** Must match your Python installation (usually x64).
- **Symbol Name:** The library must export `tree_sitter_pascal`.

## 2. The Chunker Script (`custom_chunkers.py`)

Create a file named `custom_chunkers.py` in your project root (or a global location). This script acts as the bridge.

```python
import pathlib
import ctypes
from ctypes import cdll, c_void_p
from tree_sitter import Language, Parser
from cocoindex_code.chunking import Chunk, TextPosition

# Update this path to your compiled grammar
LIB_PATH = r"C:\Path\To\tree-sitter-pascal-windows-x64.dll"

# Load the grammar
try:
    lib = cdll.LoadLibrary(LIB_PATH)
    language_function = getattr(lib, "tree_sitter_pascal")
    language_function.restype = c_void_p
    PASCAL_LANGUAGE = Language(language_function())
except Exception as e:
    print(f"Error loading Pascal grammar: {e}")
    PASCAL_LANGUAGE = None

def pascal_chunker(path: pathlib.Path, content: str) -> tuple[str | None, list[Chunk]]:
    """
    Syntax-aware chunking for Pascal/Delphi using Tree-Sitter.
    """
    if PASCAL_LANGUAGE is None:
        return None, []

    parser = Parser(PASCAL_LANGUAGE)
    tree = parser.parse(bytes(content, "utf8"))
    chunks = []
    
    # Nodes that should trigger a new chunk
    CHUNK_NODES = {
        "program", "unit",
        "procedure_declaration", "function_declaration",
        "constructor_declaration", "destructor_declaration",
        "type_declaration", "var_section", "const_section",
        "initialization_section", "finalization_section"
    }

    def walk(node):
        if node.type in CHUNK_NODES:
            start_pos = TextPosition(
                byte_offset=node.start_byte,
                char_offset=node.start_byte, 
                line=node.start_point[0] + 1,
                column=node.start_point[1]
            )
            end_pos = TextPosition(
                byte_offset=node.end_byte,
                char_offset=node.end_byte,
                line=node.end_point[0] + 1,
                column=node.end_point[1]
            )
            chunks.append(Chunk(
                text=content[node.start_byte:node.end_byte],
                start=start_pos, end=end_pos
            ))
            # Don't recurse into declarations (prevents nesting)
            if node.type not in {"program", "unit"}:
                return
        
        for child in node.children:
            walk(child)

    walk(tree.root_node)
    
    # Fallback for small or unstructured files
    if not chunks and content.strip():
        start_pos = TextPosition(byte_offset=0, char_offset=0, line=1, column=0)
        end_pos = TextPosition(byte_offset=len(content), char_offset=len(content), 
                               line=content.count('\n') + 1, column=0)
        chunks.append(Chunk(text=content, start=start_pos, end=end_pos))

    return "pascal", chunks
```

## 3. Project Configuration

Edit `.cocoindex_code/settings.yml` in your project to register the chunker:

```yaml
chunkers:
  - ext: pas
    module: custom_chunkers:pascal_chunker
  - ext: dpr
    module: custom_chunkers:pascal_chunker
```

## 4. Running the Indexer

When running `ccc index`, you must ensure Python can find your `custom_chunkers.py`.

### Local usage (easiest)
If the script is in your current directory:
```powershell
$env:PYTHONPATH='.'
ccc index
```

### Global usage
1. Place `custom_chunkers.py` and the `.dll` in a stable directory (e.g., `C:\tools\ccc-plugins\`).
2. Add that directory to your system `PYTHONPATH` environment variable.
3. Update your `.cocoindex_code/settings.yml` to point to the module:
   ```yaml
   chunkers:
     - ext: pas
       module: custom_chunkers:pascal_chunker
   ```
4. Now `ccc index` will work from any directory without extra flags.

## 5. Verification
Run `ccc doctor` to confirm the index includes the Pascal chunks. You can then search for Pascal-specific symbols:
```powershell
ccc search "procedure"
```
Check that the results show the `[pascal]` language tag and correctly identify procedure boundaries.
