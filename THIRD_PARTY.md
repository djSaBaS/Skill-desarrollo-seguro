# Terceros y procedencia

## Anthropic-Cybersecurity-Skills

V0.4 no redistribuye las skills externas dentro del plugin. El script opcional de instalación descarga únicamente las carpetas allowlisted desde:

`mukul975/Anthropic-Cybersecurity-Skills`

Commit fijado y revisado para esta versión:

`f76261573a539ec40c3d434ecbb9e657d26aa921`

La selección y el pin se registran en `EXTERNAL-SKILLS.lock.json`. El instalador verifica el commit, valida el nombre declarado de cada skill y añade metadatos locales de procedencia. El pin evita actualizaciones silenciosas, pero no sustituye una revisión humana del contenido externo.

El repositorio declara licencia Apache-2.0 para sus skills. Revisa siempre el contenido y la licencia upstream antes de redistribuirlas por otro canal.

La selección deliberadamente excluye skills de explotación, evasión, post-explotación, credential access, persistencia, C2 y malware deployment. El objetivo de este paquete es desarrollo defensivo.

## OWASP ASVS

La baseline de V0.4 toma como referencia conceptual OWASP Application Security Verification Standard 5.0.0. No incluye una copia completa del estándar. Los identificadores y requisitos completos deben consultarse en el proyecto oficial de OWASP.
