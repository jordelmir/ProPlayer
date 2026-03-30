# ProPlayer Elite v13.0: Guía de Uso Profesional

Bienvenido a la cima de la reproducción multimedia en macOS. Esta guía detalla cómo aprovechar al máximo el motor **Metal Pipeline v13.0**, un motor de post-procesamiento de video con calidad de estudio ("Hollywood-Grade").

## 1. Studio-Grade Enhancements (Ajustes de Renderizado)
Las capacidades matemáticas avanzadas de la GPU de tu Mac (Apple Silicon) están disponibles dentro de `Ajustes > Video`.

### Upscaling Quality / Super-Resolución (FSR 1.0 Aproximado)
Selecciona cómo tratar los videos comprimidos o de baja resolución:
*   **4K Upscale:** Escalado base purista vía interpolación Sinc de 6 toques (*Lanczos-3*). Ideal para casi todo.
*   **Ultra AI (Neural):** Lanczos + Ligero RCAS (Robust Contrast Adaptive Sharpening). Nitidez sin artefactos.
*   **Ultra 5K (Edge Directed) & Extreme 8K:** Usan interpolación matemática sub-pixel (*EASU* direccional) para forzar unos contornos y microtexturas cristalinos en un solo ciclo de reloj. **Advertencia:** Consume mucha capacidad de la GPU.
*   **Anime Adaptive:** Filtro espacial paramétrico ajustado matemáticamente para proteger las gruesas "líneas de acción" (Edge Detection) en animación japonesa, manteniendo los colores limpios.

### ACES Filmic Tone Mapping (HDR→SDR)
*   **Qué hace:** Evita que los videos grabados en HDR o Dolby Vision se vean "quemados", blancos o lavados en tu monitor SDR estándar usando las curvas base de "The Academy Color Encoding System".
*   **Recomendación:** Actívalo solo para películas HDR. 

### Temporal Noise Reduction (TNR)
*   **Qué hace:** Mezcla y compara el fotograma actual con el anterior detectando qué zonas están en movimiento y cuáles están estáticas (Cielo, paredes) para "planchar" y eliminar el ruido/grano de compresión de streaming.
*   **Recomendación:** Útil para videos de YouTube/web. **Apágalo para Animación/Anime** para evitar trazos sombra (ghosting).

### Color Temperature / Film Grain
*   **Kelvin Slider:** Si lo pones a 4500K obtendrás luz ambarina/cálida para sesiones nocturnas; si lo pones a 7500K forzarás blancos fríos de laboratorio.
*   **Film Grain:** Inyecta "ruido rosa matemático" variable según la luminancia del píxel para imitar rollos de 35mm. Usa 5% para un "Vintage Cinematic Look", lo que además elimina el 'banding' de color en las sombras.

## 2. Flujo de Trabajo y UX
*   **Arrastrar y Soltar**: La UI te permite agarrar tu video (`.mp4`, `.mov`, `.mkv` compatible) desde el Finder y lanzarlo sobre la aplicación, que pasará a modo Cine instantáneamente.
*   **Auto-Play "Zero Latency"**: El core reacciona a los milisegundos en que `AVFoundation` confirma lectura en buffer y auto-transiciona la pantalla.
*   **Espacios de Pantalla Completa**: Usa el botón estándar macOS o pulsa `F`. Gracias a la última actualización arquitectónica, esto convive perfectamente con el WindowManager del sistema operativo.

---
*ProPlayer Elite: Diseñado por ingenieros, para cinéfilos inflexibles. Top World Standard.*
