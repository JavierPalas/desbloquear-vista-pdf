# Desbloquear Vista PDF

Aplicación de escritorio para Windows (PowerShell + WinForms) que quita el bloqueo de seguridad que Windows añade a los archivos descargados de internet (la marca de zona `Zone.Identifier`), evitando avisos de seguridad o restricciones al abrirlos (por ejemplo, la "Vista Previa" restringida de los PDF).

## Funcionalidades

- **Arrastrar y soltar**: suelta archivos o carpetas sobre la zona indicada, o haz clic para elegir una carpeta con el explorador moderno de Windows. Desbloquea todo su contenido de forma recursiva.
- **Vigilante de descargas**: vigila una carpeta (por defecto, tu carpeta de Descargas) y desbloquea automáticamente cada archivo nuevo que aparezca en ella. Se activa solo al arrancar el programa.
- **Arranque con Windows**: botón para instalar/quitar una tarea programada que inicia el vigilante en segundo plano al iniciar sesión.
- **Archivos de hoy**: desbloquea de una vez todos los archivos creados hoy en la carpeta vigilada.
- **Registro de actividad**: log con marca de hora de cada acción realizada.

La carpeta vigilada se recuerda entre sesiones (se guarda en `config.json` al cambiarla, ya sea con el selector o escribiéndola directamente).

## Archivos del proyecto

| Archivo | Descripción |
|---|---|
| `Desbloquear Vista PDF.ps1` | Código fuente del programa (PowerShell + WinForms). |
| `Desbloquear Vista PDF.exe` | Versión compilada del script (con [ps2exe](https://github.com/MScholtes/PS2EXE)), para ejecutar sin abrir una consola. |
| `Abrir Desbloquear Vista PDF.bat` | Lanzador que ejecuta el `.ps1` con la política de ejecución necesaria. |
| `config.json` | Configuración persistente (carpeta vigilada). |

## Uso

Ejecuta cualquiera de estas opciones:

- `Desbloquear Vista PDF.exe` (doble clic).
- `Abrir Desbloquear Vista PDF.bat` (doble clic).
- El script directamente: `powershell -ExecutionPolicy Bypass -File "Desbloquear Vista PDF.ps1"`.

> Si el `.exe` está bloqueado por una política de seguridad corporativa (Device Guard/AppLocker), usa el `.bat` o el `.ps1` en su lugar.

### Instalación portable

Los tres ficheros (`.exe`, `.ps1`, `.bat`) localizan `config.json` en su propia carpeta en tiempo de ejecución, así que puedes copiar toda la carpeta del proyecto a otro equipo y funcionará igual. Si la carpeta vigilada guardada en `config.json` no existe en el nuevo equipo, simplemente elige una nueva desde la aplicación.

## Requisitos

- Windows con PowerShell (incluido de serie) y .NET Framework (para WinForms).
- Para recompilar el `.exe` tras modificar el `.ps1`, el módulo [ps2exe](https://www.powershellgallery.com/packages/ps2exe):

  ```powershell
  Install-Module -Name ps2exe -Scope CurrentUser
  Invoke-ps2exe -inputFile "Desbloquear Vista PDF.ps1" -outputFile "Desbloquear Vista PDF.exe" -noConsole -title "Desbloquear Vista PDF" -x64
  ```
