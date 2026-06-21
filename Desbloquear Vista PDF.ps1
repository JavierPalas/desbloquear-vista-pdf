Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$appName = "Desbloquear Vista PDF"
$taskName = "DesbloquearVistaPDF"
$legacyTaskName = "DesbloqueadorDescargas"

# ---------------------------------------------------------------------------
# Config persistente
# ---------------------------------------------------------------------------
$configPath = Join-Path $PSScriptRoot "config.json"

function CargarConfig {
    if (Test-Path $configPath) {
        try { return Get-Content $configPath -Raw | ConvertFrom-Json }
        catch {}
    }
    return [PSCustomObject]@{ carpetaVigilada = "$env:USERPROFILE\Downloads" }
}

function GuardarConfig($cfg) {
    $cfg | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
}

$script:config = CargarConfig

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Log($mensaje, $color = "LightGreen") {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logBox.SelectionStart  = $logBox.TextLength
    $logBox.SelectionLength = 0
    $logBox.SelectionColor  = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $logBox.AppendText("[$timestamp] ")
    $hex = switch ($color) {
        "LightGreen" { "#00C864" }
        "Orange"     { "#FFA040" }
        "Red"        { "#FF5555" }
        "Cyan"       { "#40C8FF" }
        default      { "#FFFFFF"  }
    }
    $logBox.SelectionColor = [System.Drawing.ColorTranslator]::FromHtml($hex)
    $logBox.AppendText("$mensaje`n")
    $logBox.ScrollToCaret()
}

function DesbloquearRuta($ruta) {
    $ok = 0; $err = 0
    if (Test-Path $ruta -PathType Container) {
        Log "Carpeta: $(Split-Path $ruta -Leaf)" "Cyan"
        Get-ChildItem -Path $ruta -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            try   { Unblock-File $_.FullName -ErrorAction Stop; $ok++ }
            catch { $err++ }
        }
    } else {
        try   { Unblock-File $ruta -ErrorAction Stop; $ok++ }
        catch { $err++ }
    }
    return @{ ok = $ok; err = $err }
}

function ObtenerCarpetaParaAbrir($rutas) {
    foreach ($ruta in $rutas) {
        if (Test-Path $ruta -PathType Container) { return $ruta }
        if (Test-Path $ruta -PathType Leaf) { return Split-Path $ruta -Parent }
    }
    return $null
}

function SeleccionarCarpetaExplorador($titulo, $rutaInicial = $null) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = $titulo
    $dlg.ShowNewFolderButton = $true
    if ($dlg.PSObject.Properties.Name -contains "UseDescriptionForTitle") {
        $dlg.UseDescriptionForTitle = $true
    }
    if ($dlg.PSObject.Properties.Name -contains "AutoUpgradeEnabled") {
        $dlg.AutoUpgradeEnabled = $true
    }
    if ($rutaInicial -and (Test-Path $rutaInicial -PathType Container)) {
        $dlg.SelectedPath = $rutaInicial
    }
    if ($dlg.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dlg.SelectedPath
    }
    return $null
}

function TareaExiste {
    foreach ($nombreTarea in @($taskName, $legacyTaskName)) {
        $null = schtasks /query /tn $nombreTarea 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Colores reutilizables
# ---------------------------------------------------------------------------
$clrFondo     = [System.Drawing.Color]::FromArgb(28, 28, 30)
$clrPanel     = [System.Drawing.Color]::FromArgb(44, 44, 46)
$clrTexto     = [System.Drawing.Color]::White
$clrSubtexto  = [System.Drawing.Color]::FromArgb(180, 180, 190)
$clrSecLabel  = [System.Drawing.Color]::FromArgb(130, 130, 140)
$clrAzul      = [System.Drawing.Color]::FromArgb(0, 122, 255)
$clrGris      = [System.Drawing.Color]::FromArgb(60, 60, 65)
$clrRojo      = [System.Drawing.Color]::FromArgb(180, 50, 50)
$clrVerde     = [System.Drawing.Color]::FromArgb(0, 200, 100)
$clrError     = [System.Drawing.Color]::FromArgb(255, 80, 80)
$clrLogFondo  = [System.Drawing.Color]::FromArgb(20, 20, 22)

function NuevoBoton($texto, $x, $y, $w, $h, $bg) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $texto
    $b.Location  = New-Object System.Drawing.Point($x, $y)
    $b.Size      = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = "Flat"
    $b.BackColor = $bg
    $b.ForeColor = $clrTexto
    $b.FlatAppearance.BorderSize = 0
    return $b
}

function NuevoLabel($texto, $x, $y, $w, $h, $font, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $texto
    $l.Location  = New-Object System.Drawing.Point($x, $y)
    $l.Size      = New-Object System.Drawing.Size($w, $h)
    $l.Font      = $font
    $l.ForeColor = $color
    return $l
}

$fontNormal = New-Object System.Drawing.Font("Segoe UI", 10)
$fontBold   = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$fontSmall  = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Bold)
$fontSub    = New-Object System.Drawing.Font("Segoe UI", 9)
$fontMono   = New-Object System.Drawing.Font("Consolas",  9)
$fontModalTitulo = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$fontModalTexto  = New-Object System.Drawing.Font("Segoe UI", 11)

# ---------------------------------------------------------------------------
# Formulario
# ---------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text            = $appName
$form.Size            = New-Object System.Drawing.Size(620, 810)
$form.StartPosition   = "CenterScreen"
$form.BackColor       = $clrFondo
$form.ForeColor       = $clrTexto
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.Font            = $fontNormal

# ---------------------------------------------------------------------------
# SECCION 1 - Drag & Drop
# ---------------------------------------------------------------------------
$form.Controls.Add((NuevoLabel "ARRASTRAR ARCHIVOS" 24 20 560 18 $fontSmall $clrSecLabel))

$dropPanel           = New-Object System.Windows.Forms.Panel
$dropPanel.Size      = New-Object System.Drawing.Size(560, 220)
$dropPanel.Location  = New-Object System.Drawing.Point(24, 44)
$dropPanel.BackColor = $clrPanel
$dropPanel.AllowDrop = $true
$dropPanel.Cursor    = [System.Windows.Forms.Cursors]::Hand

$dropTxtLbl           = NuevoLabel "Suelta aqui archivos o carpetas, o haz clic para seleccionar una carpeta" 0 22 560 36 (New-Object System.Drawing.Font("Segoe UI", 11)) $clrSubtexto
$dropTxtLbl.TextAlign = "MiddleCenter"
$dropTxtLbl.AllowDrop = $true
$dropTxtLbl.Cursor = [System.Windows.Forms.Cursors]::Hand

$dropIconLbl          = NuevoLabel "v" 0 68 560 120 (New-Object System.Drawing.Font("Wingdings", 64)) $clrAzul
$dropIconLbl.TextAlign = "MiddleCenter"
$dropIconLbl.AllowDrop = $true
$dropIconLbl.Cursor = [System.Windows.Forms.Cursors]::Hand

$dropPanel.Controls.AddRange(@($dropIconLbl, $dropTxtLbl))
$form.Controls.Add($dropPanel)

function MostrarResultadoDesbloqueo($total, $rutas) {
    [Console]::Beep(1000, 250)
    $carpetaAbrir = ObtenerCarpetaParaAbrir $rutas
    $titulo = if ($total.err -eq 0) { "Listo" } else { "Terminado con avisos" }
    $detalle = if ($total.err -eq 0) {
        "Se han desbloqueado $($total.ok) archivo(s) correctamente."
    } else {
        "Se han desbloqueado $($total.ok) archivo(s), pero $($total.err) no se pudieron desbloquear."
    }
    if ($carpetaAbrir) {
        $detalle = "$detalle`r`n`r`nAl pulsar OK se abrira la carpeta."
    }

    $modal = New-Object System.Windows.Forms.Form
    $modal.Text = "$appName - Resultado"
    $modal.Size = New-Object System.Drawing.Size(520, 260)
    $modal.StartPosition = "CenterParent"
    $modal.BackColor = $clrFondo
    $modal.ForeColor = $clrTexto
    $modal.FormBorderStyle = "FixedDialog"
    $modal.MaximizeBox = $false
    $modal.MinimizeBox = $false
    $modal.ShowInTaskbar = $false
    $modal.Font = $fontModalTexto

    $lblTitulo = NuevoLabel $titulo 28 24 450 34 $fontModalTitulo $clrTexto
    $lblDetalle = NuevoLabel $detalle 30 76 450 84 $fontModalTexto $clrSubtexto

    $btnOk = NuevoBoton "OK" 360 170 110 34 $clrAzul
    $btnOk.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnOk.Add_Click({
        $modal.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $modal.Close()
    })

    $modal.Controls.AddRange(@($lblTitulo, $lblDetalle, $btnOk))
    $modal.AcceptButton = $btnOk

    if ($modal.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($carpetaAbrir -and (Test-Path $carpetaAbrir -PathType Container)) {
            Start-Process explorer.exe -ArgumentList "`"$carpetaAbrir`""
        }
    }
}

function DesbloquearRutas($rutas) {
    $rutas = @($rutas)
    $total = @{ ok = 0; err = 0 }
    foreach ($ruta in $rutas) {
        $r = DesbloquearRuta $ruta
        $total.ok  += $r.ok
        $total.err += $r.err
    }
    if ($total.err -eq 0) {
        Log "Resultado: $($total.ok) archivo(s) desbloqueado(s)" "LightGreen"
    } else {
        Log "Resultado: $($total.ok) OK  |  $($total.err) con error" "Orange"
    }
    MostrarResultadoDesbloqueo $total $rutas
}

$onDragEnter = {
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        $dropPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 70, 160)
    }
}
$onDragLeave = { $dropPanel.BackColor = $clrPanel }
$onDragDrop  = {
    param($s, $e)
    $dropPanel.BackColor = $clrPanel
    DesbloquearRutas $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
}
$onDropClick = {
    $carpeta = SeleccionarCarpetaExplorador "Selecciona la carpeta a desbloquear" $script:config.carpetaVigilada
    if ($carpeta) {
        DesbloquearRutas @($carpeta)
    }
}
foreach ($ctrl in @($dropPanel, $dropIconLbl, $dropTxtLbl)) {
    $ctrl.Add_DragEnter($onDragEnter)
    $ctrl.Add_DragLeave($onDragLeave)
    $ctrl.Add_DragDrop($onDragDrop)
    $ctrl.Add_Click($onDropClick)
}

# ---------------------------------------------------------------------------
# SECCION 2 - Vigilante
# ---------------------------------------------------------------------------
$form.Controls.Add((NuevoLabel "VIGILANTE DE DESCARGAS" 24 288 560 18 $fontSmall $clrSecLabel))

$watchPanel           = New-Object System.Windows.Forms.Panel
$watchPanel.Size      = New-Object System.Drawing.Size(560, 116)
$watchPanel.Location  = New-Object System.Drawing.Point(24, 314)
$watchPanel.BackColor = $clrPanel

$watchPanel.Controls.Add((NuevoLabel "Desbloquea automaticamente cada archivo que entre en la carpeta:" 16 12 520 22 $fontSub $clrSubtexto))

$txtCarpeta             = New-Object System.Windows.Forms.TextBox
$txtCarpeta.Text        = $script:config.carpetaVigilada
$txtCarpeta.Font        = $fontSub
$txtCarpeta.BackColor   = [System.Drawing.Color]::FromArgb(30, 30, 32)
$txtCarpeta.ForeColor   = $clrTexto
$txtCarpeta.BorderStyle = "None"
$txtCarpeta.Location    = New-Object System.Drawing.Point(16, 44)
$txtCarpeta.Size        = New-Object System.Drawing.Size(412, 22)
$watchPanel.Controls.Add($txtCarpeta)

$btnExaminar = NuevoBoton "..." 440 40 42 28 $clrGris
$btnExaminar.Add_Click({
    $carpeta = SeleccionarCarpetaExplorador "Selecciona la carpeta a vigilar" $txtCarpeta.Text
    if ($carpeta) {
        $txtCarpeta.Text = $carpeta
        $script:config.carpetaVigilada = $carpeta
        GuardarConfig $script:config
        Log "Carpeta cambiada a: $carpeta" "Cyan"
        if ($script:watcherActivo) { $btnToggle.PerformClick(); $btnToggle.PerformClick() }
    }
})
$watchPanel.Controls.Add($btnExaminar)

$lblWatchStatus           = NuevoLabel "Estado: Inactivo" 16 82 190 22 $fontBold $clrError
$btnToggle  = NuevoBoton "Activar"        336 78 96  30 $clrAzul
$btnStartup = NuevoBoton "Instalar inicio" 448 78 96 30 $clrGris
$watchPanel.Controls.AddRange(@($lblWatchStatus, $btnToggle, $btnStartup))
$form.Controls.Add($watchPanel)

# ---------------------------------------------------------------------------
# Logica watcher
# ---------------------------------------------------------------------------
$script:watcherActivo  = $false
$script:fsWatcher      = $null
$script:fsTimer        = $null
$script:pendingUnblock = [System.Collections.Generic.Dictionary[string,hashtable]]::new()

function ActualizarUI {
    if ($script:watcherActivo) {
        $lblWatchStatus.Text      = "Estado: Activo"
        $lblWatchStatus.ForeColor = $clrVerde
        $btnToggle.Text           = "Desactivar"
        $btnToggle.BackColor      = $clrRojo
    } else {
        $lblWatchStatus.Text      = "Estado: Inactivo"
        $lblWatchStatus.ForeColor = $clrError
        $btnToggle.Text           = "Activar"
        $btnToggle.BackColor      = $clrAzul
    }
    if (TareaExiste) {
        $btnStartup.Text      = "Quitar inicio"
        $btnStartup.BackColor = [System.Drawing.Color]::FromArgb(100, 50, 50)
    } else {
        $btnStartup.Text      = "Instalar inicio"
        $btnStartup.BackColor = $clrGris
    }
}

$btnToggle.Add_Click({
    if (-not $script:watcherActivo) {
        $carpeta = $txtCarpeta.Text.Trim()
        if (-not (Test-Path $carpeta -PathType Container)) {
            Log "Carpeta no encontrada: $carpeta" "Red"; return
        }

        # FileSystemWatcher encola eventos; sin -Action, van a la cola de PowerShell
        $script:fsWatcher = New-Object System.IO.FileSystemWatcher
        $script:fsWatcher.Path                  = $carpeta
        $script:fsWatcher.NotifyFilter          = [System.IO.NotifyFilters]::FileName
        $script:fsWatcher.IncludeSubdirectories = $false
        $script:fsWatcher.EnableRaisingEvents   = $true
        Register-ObjectEvent $script:fsWatcher "Created" -SourceIdentifier "FSW_Created" | Out-Null
        Register-ObjectEvent $script:fsWatcher "Renamed" -SourceIdentifier "FSW_Renamed" | Out-Null

        # Timer en el hilo UI: procesa la cola y reintenta desbloqueos
        $script:fsTimer          = New-Object System.Windows.Forms.Timer
        $script:fsTimer.Interval = 400
        $script:fsTimer.Add_Tick({
            # Recoger nuevos eventos de la cola
            foreach ($sid in @("FSW_Created","FSW_Renamed")) {
                $evs = Get-Event -SourceIdentifier $sid -ErrorAction SilentlyContinue
                if (-not $evs) { continue }
                foreach ($ev in @($evs)) {
                    Remove-Event -EventIdentifier $ev.EventIdentifier -ErrorAction SilentlyContinue
                    $ruta   = $ev.SourceEventArgs.FullPath
                    $nombre = [System.IO.Path]::GetFileName($ruta)
                    $ext    = [System.IO.Path]::GetExtension($nombre).ToLower()
                    if ($ext -notin @('.crdownload','.part','.tmp','.download')) {
                        if (-not $script:pendingUnblock.ContainsKey($ruta)) {
                            $script:pendingUnblock[$ruta] = @{ nombre=$nombre; intento=0; siguiente=[datetime]::Now.AddMilliseconds(800) }
                        }
                    }
                }
            }

            # Procesar cola de pendientes
            $delays  = @(800,1500,2500,4000,6000)
            $borrar  = [System.Collections.Generic.List[string]]::new()
            foreach ($ruta in $script:pendingUnblock.Keys) {
                $item = $script:pendingUnblock[$ruta]
                if ([datetime]::Now -lt $item.siguiente) { continue }
                if (-not [System.IO.File]::Exists($ruta)) { $borrar.Add($ruta); continue }
                try {
                    Unblock-File -LiteralPath $ruta -ErrorAction Stop
                    Log "Auto-desbloqueado: $($item.nombre)" "Cyan"
                    [Console]::Beep(1000, 250)
                    $borrar.Add($ruta)
                } catch {
                    $item.intento++
                    if ($item.intento -ge $delays.Count) { $borrar.Add($ruta) }
                    else { $item.siguiente = [datetime]::Now.AddMilliseconds($delays[$item.intento]) }
                }
            }
            foreach ($r in $borrar) { $script:pendingUnblock.Remove($r) }
        })
        $script:fsTimer.Start()
        $script:watcherActivo = $true
        Log "Vigilante iniciado en: $carpeta" "LightGreen"
    } else {
        $script:fsTimer.Stop()
        $script:fsTimer.Dispose()
        $script:fsTimer = $null
        $script:fsWatcher.EnableRaisingEvents = $false
        $script:fsWatcher.Dispose()
        $script:fsWatcher = $null
        Unregister-Event -SourceIdentifier "FSW_Created" -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier "FSW_Renamed" -ErrorAction SilentlyContinue
        Remove-Event     -SourceIdentifier "FSW_Created" -ErrorAction SilentlyContinue
        Remove-Event     -SourceIdentifier "FSW_Renamed" -ErrorAction SilentlyContinue
        $script:pendingUnblock.Clear()
        $script:watcherActivo = $false
        Log "Vigilante detenido" "Orange"
    }
    ActualizarUI
})

$btnStartup.Add_Click({
    $scriptPath = $PSCommandPath
    if (TareaExiste) {
        schtasks /delete /tn $taskName /f 2>$null | Out-Null
        schtasks /delete /tn $legacyTaskName /f 2>$null | Out-Null
        Log "Tarea de inicio eliminada" "Orange"
    } else {
        $cmd = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Silencioso"
        schtasks /create /tn $taskName /tr $cmd /sc ONLOGON /ru $env:USERNAME /f | Out-Null
        Log "Tarea de inicio instalada - arrancara con Windows" "LightGreen"
    }
    ActualizarUI
})

# ---------------------------------------------------------------------------
# SECCION 3 - Archivos de hoy
# ---------------------------------------------------------------------------
$form.Controls.Add((NuevoLabel "ARCHIVOS DE HOY" 24 454 560 18 $fontSmall $clrSecLabel))

$todayPanel           = New-Object System.Windows.Forms.Panel
$todayPanel.Size      = New-Object System.Drawing.Size(560, 80)
$todayPanel.Location  = New-Object System.Drawing.Point(24, 476)
$todayPanel.BackColor = $clrPanel

$todayTxtLbl = NuevoLabel "Desbloquea todos los archivos descargados hoy en la carpeta vigilada:" 0 10 560 22 $fontSub $clrSubtexto
$todayTxtLbl.TextAlign = "MiddleCenter"
$todayPanel.Controls.Add($todayTxtLbl)

$btnHoy = NuevoBoton "Desbloquear archivos de hoy" 180 38 200 34 $clrVerde
$btnHoy.Font = $fontBold
$btnHoy.Add_Click({
    $carpeta = $txtCarpeta.Text.Trim()
    if (-not (Test-Path $carpeta -PathType Container)) {
        Log "Carpeta no encontrada: $carpeta" "Red"; return
    }
    $hoy = (Get-Date).Date
    $archivos = Get-ChildItem -Path $carpeta -File -ErrorAction SilentlyContinue |
        Where-Object { $_.CreationTime.Date -eq $hoy }
    if (-not $archivos) {
        Log "No hay archivos de hoy en: $(Split-Path $carpeta -Leaf)" "Orange"; return
    }
    $ok = 0; $err = 0
    foreach ($f in $archivos) {
        try   { Unblock-File $f.FullName -ErrorAction Stop; $ok++ }
        catch { $err++ }
    }
    Log "Archivos de hoy: $ok desbloqueado(s)" "LightGreen"
    MostrarResultadoDesbloqueo @{ ok = $ok; err = $err } @($carpeta)
})
$todayPanel.Controls.Add($btnHoy)
$form.Controls.Add($todayPanel)

# ---------------------------------------------------------------------------
# SECCION 4 - Log
# ---------------------------------------------------------------------------
$form.Controls.Add((NuevoLabel "ACTIVIDAD" 24 578 240 18 $fontSmall $clrSecLabel))

$btnLimpiar = NuevoBoton "Limpiar" 504 576 80 22 $clrGris
$btnLimpiar.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$btnLimpiar.ForeColor = $clrSubtexto
$btnLimpiar.Add_Click({ $logBox.Clear() })
$form.Controls.Add($btnLimpiar)

$logBox             = New-Object System.Windows.Forms.RichTextBox
$logBox.Size        = New-Object System.Drawing.Size(560, 172)
$logBox.Location    = New-Object System.Drawing.Point(24, 602)
$logBox.BackColor   = $clrLogFondo
$logBox.ForeColor   = $clrVerde
$logBox.Font        = $fontMono
$logBox.ReadOnly    = $true
$logBox.BorderStyle = "None"
$logBox.ScrollBars  = "Vertical"
$form.Controls.Add($logBox)

# ---------------------------------------------------------------------------
# Inicio
# ---------------------------------------------------------------------------
$silencioso = $args -contains "-Silencioso"

$form.Add_Shown({
    ActualizarUI
    Log "$appName listo." "LightGreen"
    Log "Carpeta vigilada: $($script:config.carpetaVigilada)" "Cyan"
    if ($silencioso) {
        $btnToggle.PerformClick()
        $form.WindowState   = "Minimized"
        $form.ShowInTaskbar = $false
    }
})

[void]$form.ShowDialog()
