"""
Arkher AI - motor de geração (Python puro, sem dependências externas).

Tudo aqui funciona com a biblioteca padrão do Python 3.10+:
  * pnglib    -> encoder PNG (RGB / RGBA / cinza) escrito na mão
  * glb        -> writer glTF 2.0 binário (.glb) com materiais PBR, skin e animações
  * meshes     -> primitivas e modelos compostos (herói, árvore, pedra, espada, casa...)
  * textures   -> mapas PBR procedurais (albedo/normal/roughness/metallic/AO/height)
  * noise      -> value noise + fBm + Worley (semeado e determinístico)

Se numpy estiver instalado, os módulos usam automaticamente (fica 10-100x mais
rápido em texturas 8k/16k). Sem numpy, continua funcionando em Python puro.
"""

__version__ = "1.0.0"
__all__ = ["pnglib", "glb", "meshes", "textures", "noise"]

try:  # pragma: no cover - depende do ambiente
    import numpy as _np  # noqa: F401

    HAS_NUMPY = True
except Exception:  # pragma: no cover
    HAS_NUMPY = False
