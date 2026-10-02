$port = 8080
$root = $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Servidor en http://localhost:$port/"

# Lee BE_LABEL desde Code.gs (única fuente). Si no lo encuentra, falla al fallback.
function Get-BeLabel {
    $codePath = Join-Path $root 'Code.gs'
    if (Test-Path $codePath -PathType Leaf) {
        $m = [regex]::Match([System.IO.File]::ReadAllText($codePath), "const\s+BE_LABEL\s*=\s*[`"']([^`"']+)[`"']")
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return ''
}

# Igual que include() en AppScript: reemplaza <?!= include('archivo'); ?>
# por el contenido de "archivo.html" (un solo nivel, suficiente para _nav).
function Expand-Includes([string]$text) {
    return [regex]::Replace($text, "<\?!=\s*include\('([^']+)'\);?\s*\?>", {
        param($m)
        $inc = Join-Path $root ($m.Groups[1].Value + '.html')
        if (Test-Path $inc -PathType Leaf) { [System.IO.File]::ReadAllText($inc) } else { '' }
    })
}

# Reemplaza el scriptlet <?= BE_LABEL ?> por el valor real (espejo de Code.gs).
function Expand-BeLabel([string]$text) {
    $be = Get-BeLabel
    return [regex]::Replace($text, "<\?=\s*BE_LABEL\s*\?>", $be)
}

# En preview local no hay login, así que tratamos al dev como admin (true)
# para que se vea la pestaña "Email". En producción lo resuelve doGet/include.
function Expand-EmailAdmin([string]$text) {
    return [regex]::Replace($text, "<\?=\s*EMAIL_ADMIN\s*\?>", 'true')
}

# Ídem para la pestaña "Analytics" (ANALYTICS_VIEWER): en preview siempre visible.
function Expand-AnalyticsViewer([string]$text) {
    return [regex]::Replace($text, "<\?=\s*ANALYTICS_VIEWER\s*\?>", 'true')
}

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $path = $req.Url.LocalPath.TrimStart('/')
    if ($path -eq '' -or $path -eq '/') { $path = '5_Grafico_vs_Target.html' }
    $file = Join-Path $root $path
    if (Test-Path $file -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($file).ToLower()
        $mime = switch ($ext) {
            '.html' { 'text/html; charset=utf-8' }
            '.js'   { 'application/javascript' }
            '.css'  { 'text/css' }
            default { 'application/octet-stream' }
        }
        if ($ext -eq '.html') {
            $text  = Expand-Includes ([System.IO.File]::ReadAllText($file))
            $text  = Expand-BeLabel $text
            $text  = Expand-EmailAdmin $text
            $text  = Expand-AnalyticsViewer $text
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        } else {
            $bytes = [System.IO.File]::ReadAllBytes($file)
        }
        $res.ContentType = $mime
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $res.StatusCode = 404
    }
    $res.OutputStream.Close()
}
