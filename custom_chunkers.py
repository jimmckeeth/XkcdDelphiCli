import pathlib
import ctypes
from ctypes import cdll, c_void_p
from tree_sitter import Language, Parser
from cocoindex_code.chunking import Chunk, TextPosition

# Path to the compiled tree-sitter-pascal library
# We'll use the x64 version as we are on a 64-bit system.
LIB_PATH = r"C:\Tools\ccc-plugins\tree-sitter-pascal-windows-x64.dll"

# Load the grammar
# In tree-sitter 0.21+, we use ctypes to get the function pointer and pass it to Language()
# Note: The symbol name is usually tree_sitter_pascal
try:
    lib = cdll.LoadLibrary(LIB_PATH)
    language_function = getattr(lib, "tree_sitter_pascal")
    language_function.restype = c_void_p
    PASCAL_LANGUAGE = Language(language_function())
except Exception as e:
    print(f"Error loading Pascal grammar from {LIB_PATH}: {e}")
    PASCAL_LANGUAGE = None

def pascal_chunker(path: pathlib.Path, content: str) -> tuple[str | None, list[Chunk]]:
    """
    Custom chunker for Pascal/Delphi files using a custom tree-sitter grammar.
    """
    # print(f"DEBUG: Calling pascal_chunker for {path}")
    if PASCAL_LANGUAGE is None:
        return None, []

    parser = Parser(PASCAL_LANGUAGE)
    tree = parser.parse(bytes(content, "utf8"))
    
    chunks = []
    
    # Define which nodes we want to treat as standalone chunks
    # We want top-level declarations and significant sections.
    CHUNK_NODES = {
        "program",
        "unit",
        "procedure_declaration",
        "function_declaration",
        "constructor_declaration",
        "destructor_declaration",
        "type_declaration",
        "var_section",
        "const_section",
        "resourcestring_section",
        "initialization_section",
        "finalization_section"
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
            
            text = content[node.start_byte:node.end_byte]
            
            chunks.append(Chunk(
                text=text,
                start=start_pos,
                end=end_pos
            ))
            
            if node.type not in {"program", "unit"}:
                return
        
        for child in node.children:
            walk(child)

    walk(tree.root_node)
    
    if not chunks and content.strip():
        start_pos = TextPosition(byte_offset=0, char_offset=0, line=1, column=0)
        end_pos = TextPosition(byte_offset=len(content), char_offset=len(content), line=content.count('\n') + 1, column=0)
        chunks.append(Chunk(text=content, start=start_pos, end=end_pos))

    return "pascal", chunks
