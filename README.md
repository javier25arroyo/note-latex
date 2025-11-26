# Entorno LaTeX auto-contenido para Windows (sin Docker/WSL)

Este proyecto proporciona scripts de PowerShell para configurar y compilar LaTeX en Windows 10/11 sin usar Docker ni WSL. Si tienes winget o Chocolatey, se instalará MiKTeX de forma normal; si no, el script descarga una instalación "portátil" dentro de `./latex-env/miktex`, evitando una instalación global y privilegios de administrador.

## Requisitos
- Windows 10/11
- PowerShell 5.0 o superior
- Conexión a Internet (para descargar/instalar MiKTeX)
- (Opcional) winget o Chocolatey

## Estructura creada
```
./latex-env/
  src/        # Tus .tex
  build/      # PDFs y artefactos de compilación
  logs/       # Logs .log de la compilación
  templates/  # Plantillas opcionales
```

## Configuración (una sola vez)
1) Abre PowerShell en este directorio y (si fuera necesario) permite scripts para la sesión actual:
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

2) Ejecuta el setup:
   .\setup-latex-env.ps1

   - Si tienes winget/choco, puede pedir elevación para instalar MiKTeX.
   - Si NO quieres instalar nada globalmente, el script intentará una instalación portátil en `./latex-env/miktex`.
   - El script verifica que `pdflatex` y `latexmk` estén disponibles; si no, mostrará un error claro.

## Uso
- Compilación rápida (recomendado):
  .\build.ps1

- O bien, cargar la función y compilar explícitamente:
  . .\setup-latex-env.ps1
  Invoke-LatexBuild -Path '.\latex-env\src\main.tex'

- Edita tu documento en `./latex-env/src/` (se crea un `main.tex` de ejemplo). La salida PDF queda en `./latex-env/build/` y los logs en `./latex-env/logs/`.

## Verificación rápida
1) Ejecuta:  .\build.ps1
2) Comprueba que se generó `./latex-env/build/main.pdf` y que existen logs en `./latex-env/logs/`.

## Solución de problemas
- Permisos/UAC: La instalación con winget/choco puede requerir PowerShell como Administrador. Si no quieres elevar, confía en la instalación portátil.
- PATH en la sesión: El script añade automáticamente rutas típicas de MiKTeX (incluida la portable) al PATH de la sesión. Si tras instalar no se detecta `pdflatex/latexmk`, cierra y abre una nueva consola, o agrega manualmente:
  - C:\Program Files\MiKTeX\miktex\bin\x64
  - C:\Program Files (x86)\MiKTeX\miktex\bin
- latexmk ausente: MiKTeX puede instalar paquetes bajo demanda. Ejecuta el build y acepta la instalación si MiKTeX lo solicita.

## Nota
- No se usa Docker ni WSL por decisión de diseño; el flujo soporta instalación portátil local a la carpeta del proyecto para evitar instalaciones globales.