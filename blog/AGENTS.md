# Contexto del Proyecto: Generador de Blog Estático

Este documento proporciona contexto a los asistentes de IA o agentes sobre la estructura y arquitectura de este proyecto.

## Arquitectura Principal
- **Core:** El proyecto es un generador de sitios estáticos ("SSG") customizado y escrito en Python 3 (`blog-build.py`). Convierte archivos Markdown a HTML estático en el directorio actual.
- **Pipelines:**
  - Lógica procesada a través de `MarkdownIt` combinada con Pygments para realce de sintaxis de código.
  - El generador utiliza `ThreadPoolExecutor` para iterar archivos asincrónicamente y reducir tiempos de compilación.
  - Implementa "Construcción Incremental": solo regenera HTMLs si el archivo `.md`, el script o las plantillas relevantes han sido modificadas recientemente respecto al destino compilado.

## Directorios y Estructuras
- `_contents/`: Directorio origen que debe contener todos los archivos Markdown (`.md`) para las entradas del blog. Usan "Frontmatter" YAML para definir la metadata del post (ej. `title`, `date`, `tags`).
- `_templates/`: Contiene las plantillas [Jinja2](https://jinja.palletsprojects.com/) que le dan formato a la web (`base.html`, `lists.html`). El diseño está preparado para trabajar modularmente (`_header.html`, `_footer.html`).
- `css/`: Hojas de estilo puras. Utiliza preferentemente CSS moderno con variables y `clamp()` para diseños responsivos, evitando frameworks pesados o utilidades excesivas. `main.css` es la hoja master.
- `img/`: Directorio de imágenes estáticas y assets web (favicon, logos en svg).

## Desarrollo e Iteración

### Iniciar y Compilar

1. Las dependencias requeridas se asumen preinstaladas o se manejan por el entorno: `markdown-it-py`, `jinja2`, `pygments`, `python-frontmatter`, `mdit-py-plugins`.

2. Para compilar una nueva versión de la web, ejecuta el script desde la raíz del proyecto. El script usa `argparse` para la configuración:
   ```bash
   python3 blog-build.py --site-name "Mi Web" --site-url "https://midominio.com"
   ```
   *(Este comando procesará rutas de archivos `.md`, tags, categorías y generará paginación y directorios de estructura automáticamente).*

### Reglas para Agentes (Guidelines)

- **Aesthetics First:** Cualquier adición al UI debe respetar los lineamientos del CSS Vanilla moderno (usando preferiblemente CSS Variables para colores de texto y fondos, y asegurando compatibilidad con esquemas oscuros como `prefers-color-scheme`). No añadas código basura en frameworks de terceros salvo que el usuario lo pida.

- **Consistencia MVC:** Mantén la segregación estricta. Todo el procesamiento de datos I18n, manipulación de horas/fechas o control de estados se debe calcular en el archivo Python principal (`blog-build.py`) inyectando objetos limpios a las plantillas HTML a la hora de compilar. Evita bloqueos y lógica condicional compleja dentro de los templates Jinja2.
