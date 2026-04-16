# Proyecto: Juego de la Vida en WebAssembly

Este proyecto es una modernización y optimización de una implementación ![existente](https://github.com/jpulgarin/canvaslife) de *El Juego de la Vida*, trasladando el motor de cálculo principal de JavaScript a **WebAssembly (WASM)**. El objetivo principal ha sido reducir la huella de código y la sobrecarga de JavaScript a su mínima expresión.

## Arquitectura

- **Motor WebAssembly (`life.wat` / `life.wasm`)**: Implementado nativamente usando *WebAssembly Text Format (WAT)*. 
  - Expone un entorno de memoria compartida donde cada estado de la célula (viva/muerta) se mapea como un byte en memoria.
  - El algoritmo central para evolucionar las células iterando usando las reglas de Conway se ejecuta directa y eficientemente dentro del entorno WASM. Utiliza la técnica de *Double Buffering* (Doble Búfer) puramente manejada por la máquina virtual, prescindiendo del Garbage Collector de JavaScript.
- **Frontend Minimalista (`index.html`)**: Actúa como una ligera capa pegamento (*glue code*).
  - Sustituye en su totalidad el antiguo archivo unificado `canvaslife.js`.
  - Carga los recursos del DOM de forma asíncrona, instancia e interactúa con la memoria compilada del WASM.
  - Elimina todas las dependencias a librerías externas voluminosas que se utilizaban para las solicitudes, notablemente **jQuery**, remplazadas por las APIs nativas como `fetch()`. Todo el renderizado y los eventos de clic utilizan Vanilla JavaScript.

## Archivos Relevantes

1. **`life.wat`**: Código fuente primario escrito en WAT. Maneja el arreglo multidimensional calculando colisiones en los contornos toroidales de una forma sumamente optimizada.
2. **`life.wasm`**: Módulo binario producido tras correr el compilador `wat2wasm` al código fuente, usado para la carga del cliente web.
3. **`index.html`**: Punto de entrada a la web y capa de encapsulamiento. Proporciona en su interior la clase `GameEngine`, la cual administra responsable y unificadamente la sincronización de cuadros, los eventos del DOM (ratón y táctil), el motor hiper-rápido `ImageData` y el parseador de archivos RLE.

## Optimizaciones de Rendimiento y UX

Con el propósito de lograr la máxima eficiencia posible en el navegador:
- **Renderizado por Píxel (ImageData)**: Se sustituyó por completo el volátil pre-renderizado de contextos 2D (`fillRect`) a favor de inyectar bytes (RGAB) directamente en un bloque de memoria interconectado mediante `ImageData`. 
- **Ciclo de Animación y Fluidez**: El motor utiliza `requestAnimationFrame` en combinación con marcas de tiempo temporales (`performance.now()`) para evaluar los deltas de retardo del simulador sin recurrir al obsoleto modelo de bloqueo de eventos del `setInterval`.
- **Estructura Escalable e Interactividad**: La lógica ahora habita limpia en un diseño orientado a objetos con la estructura `GameEngine`. Se incluyó soporte nativo táctil de alto nivel para manipulación sin ratón, y el parser RLE ha sido refinado para lidiar con saltos posicionales avanzados y comentarios con signo métrico (`#`).

## Resultado

Gracias a esta refactorización, el uso de JavaScript se centró pura y estrictamente en las tareas no tolerables para WebAssembly (como manipulaciones directas en el árbol DOM y el procesamiento XHR de las figuras rle). La ejecución computacional del canvas es ahora abrumadoramente más rápida, logrando una evolución algorítmica impecable y eliminando una dependencia JavaScript innecesaria.

Puede levantarse temporalmente el proyecto corriendo un servidor de archivos en la carpeta (`python -m http.server`) y acceder a http://localhost:8000.
