"""
Validador dos arquivos gerados para Godot (.tscn / .tres / project.godot).

Não é o parser do Godot, mas pega os erros que realmente quebram a importação:
  * load_steps errado
  * ExtResource/SubResource apontando para id inexistente
  * [node] sem type e sem instance (exceto a raiz)
  * parent apontando para nó que não existe
  * caminho de arquivo externo ausente no projeto
  * project.godot: chaves duplicadas ou seção inexistente

Usado pelos testes automatizados e disponível como função para o servidor
responder "o que foi validado" na UI.
"""
from __future__ import annotations

import re
from typing import Dict, List, Tuple

__all__ = ["validate_scene", "validate_resource", "validate_project_godot", "validate_files"]

_HEADER = re.compile(r'^\[(gd_scene|gd_resource|ext_resource|sub_resource|node|connection|editable)\b(.*)\]$')
_ATTR = re.compile(r'([\w_/-]+)=(?:"([^"]*)"|([^ \]]+))')


def _parse_attrs(text: str) -> Dict[str, str]:
    return {k: (v1 if v1 != "" or v2 is None else v2) for k, v1, v2 in _ATTR.findall(text)}


def validate_scene(text: str, project_files: Dict[str, object] | None = None) -> List[str]:
    errors: List[str] = []
    lines = text.splitlines()
    if not lines:
        return ["arquivo vazio"]

    header = _parse_attrs(lines[0][1:-1] if lines[0].startswith("[") else "")
    if not lines[0].startswith("[gd_scene") and not lines[0].startswith("[gd_resource"):
        errors.append(f"cabeçalho inválido: {lines[0][:60]}")
    fmt = header.get("format")
    if fmt not in ("2", "3"):
        errors.append(f"format={fmt} inválido (use 3 para Godot 4)")

    ext_ids: set[str] = set()
    sub_ids: set[str] = set()
    node_paths: set[str] = {"."}
    declared: List[str] = []
    ext_paths: List[str] = []

    for raw in lines[1:]:
        line = raw.strip()
        m = _HEADER.match(line)
        if not m:
            continue
        kind, rest = m.group(1), m.group(2)
        attrs = _parse_attrs(rest)
        if kind == "ext_resource":
            rid = attrs.get("id")
            if not rid:
                errors.append("ext_resource sem id")
            elif rid in ext_ids:
                errors.append(f"id de ext_resource duplicado: {rid}")
            ext_ids.add(rid or "")
            if attrs.get("path"):
                ext_paths.append(attrs["path"])
        elif kind == "sub_resource":
            rid = attrs.get("id")
            if not rid:
                errors.append("sub_resource sem id")
            elif rid in sub_ids:
                errors.append(f"id de sub_resource duplicado: {rid}")
            sub_ids.add(rid or "")
            declared.append(f"sub:{rid}")
        elif kind == "node":
            name = attrs.get("name")
            parent = attrs.get("parent", ".")
            if not name:
                errors.append("node sem name")
            if not attrs.get("type") and not attrs.get("instance"):
                errors.append(f'node "{name}" sem type e sem instance')
            if parent not in node_paths:
                errors.append(f'node "{name}": parent "{parent}" não existe')
            full = name if parent == "." else f"{parent}/{name}"
            if full in node_paths:
                errors.append(f"caminho de nó duplicado: {full}")
            node_paths.add(full)

    # load_steps = ext + sub + 1
    ls = header.get("load_steps")
    if ls is not None:
        expected = len(ext_ids) + len(sub_ids) + 1
        if not ls.isdigit() or int(ls) != expected:
            errors.append(f"load_steps={ls}, esperado {expected} ({len(ext_ids)} ext + {len(sub_ids)} sub + 1)")

    # referências
    for rid in re.findall(r'ExtResource\("([^"]+)"\)', text):
        if rid not in ext_ids:
            errors.append(f'ExtResource("{rid}") não declarada')
    for rid in re.findall(r'SubResource\("([^"]+)"\)', text):
        if rid not in sub_ids:
            errors.append(f'SubResource("{rid}") não declarada')

    # caminhos externos
    if project_files is not None:
        for p in ext_paths:
            if p.startswith("res://"):
                rel = p[len("res://"):]
                if rel not in project_files:
                    errors.append(f"caminho externo não existe no projeto: {p}")
            elif p.startswith("uid://"):
                continue
            else:
                errors.append(f"caminho de recurso inválido: {p}")

    return errors


def validate_resource(text: str) -> List[str]:
    return validate_scene(text)


def validate_project_godot(text: str, project_files: Dict[str, object] | None = None) -> List[str]:
    errors: List[str] = []
    section = None
    seen: Dict[str, List[str]] = {}
    sections = set()
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith(";") or s.startswith("#"):
            continue
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1]
            if section in sections:
                errors.append(f"seção duplicada: [{section}]")
            sections.add(section)
            continue
        if "=" not in s:
            # continuação de valor multilinha (input map) -> ok
            continue
        key = s.split("=", 1)[0].strip()
        full = f"{section}/{key}"
        seen.setdefault(full, []).append(s)
    dupes = [k for k, v in seen.items() if len(v) > 1]
    for d in dupes:
        errors.append(f"chave duplicada em project.godot: {d}")

    for required in ("application", "rendering", "input"):
        if required not in sections:
            errors.append(f"seção obrigatória ausente: [{required}]")

    if project_files is not None:
        for ref in re.findall(r'"(res://[^"]+)"', text):
            rel = ref[len("res://"):]
            rel = rel.split('"')[0]
            if rel and rel not in project_files and "*" + rel not in project_files:
                # autoloads usam "*res://..."
                errors.append(f"project.godot referencia arquivo inexistente: {ref}")
    return errors


def validate_files(files: Dict[str, object]) -> Dict[str, List[str]]:
    """Valida todos os arquivos Godot de um dicionário {caminho: conteúdo}."""
    report: Dict[str, List[str]] = {}
    for path, content in files.items():
        if not isinstance(content, str):
            continue
        if path.endswith(".tscn") or path.endswith(".tres"):
            errs = validate_scene(content, files)
        elif path == "project.godot":
            errs = validate_project_godot(content, files)
        else:
            continue
        if errs:
            report[path] = errs
    return report
