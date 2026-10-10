# Server locale del sito (solo su questo computer, nessuna connessione esterna necessaria).
# Serve la cartella "sito_offline" su http://localhost:PORTA e apre il browser.
# Usa sempre la stessa porta: i dati del sito restano salvati nel browser per quell'indirizzo.
param([int]$Porta = 8282, [switch]$SenzaBrowser)
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\sito_offline'))
if (-not (Test-Path (Join-Path $root 'index.html'))) {
    Write-Host 'Manca la cartella sito_offline: esegui prima compila.bat' -ForegroundColor Red
    Read-Host 'Premi Invio per chiudere'
    exit 1
}
if (-not $root.EndsWith('\')) { $root += '\' }

$mime = @{
    '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.mjs' = 'text/javascript; charset=utf-8'
    '.json' = 'application/json'; '.wasm' = 'application/wasm'; '.css' = 'text/css'; '.png' = 'image/png'
    '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.svg' = 'image/svg+xml'; '.ttf' = 'font/ttf'; '.otf' = 'font/otf'
    '.ico' = 'image/x-icon'; '.bin' = 'application/octet-stream'; '.txt' = 'text/plain; charset=utf-8'
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Porta/")
try { $listener.Start() } catch {
    Write-Host "La porta $Porta e' gia' in uso: il sito potrebbe essere gia' aperto. Apro il browser." -ForegroundColor Yellow
    Start-Process "http://localhost:$Porta/"
    exit 0
}
if (-not $SenzaBrowser) { Start-Process "http://localhost:$Porta/" }
Write-Host "Sito attivo su http://localhost:$Porta/  -  chiudi questa finestra per fermarlo." -ForegroundColor Green

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $res = $ctx.Response
    try {
        $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
        if ($rel -eq '') { $rel = 'index.html' }
        $file = [IO.Path]::GetFullPath((Join-Path $root $rel))
        # solo file dentro sito_offline (niente "../")
        if (-not $file.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
            $res.StatusCode = 404
        } else {
            $bytes = [IO.File]::ReadAllBytes($file)
            $ext = [IO.Path]::GetExtension($file).ToLower()
            $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
            $res.Headers.Add('X-Content-Type-Options', 'nosniff')
            # Verso l'esterno solo l'origine (http://localhost:PORTA), mai percorso o parametri:
            # OpenStreetMap rifiuta le tessere richieste senza Referer ("Blocked").
            $res.Headers.Add('Referrer-Policy', 'strict-origin-when-cross-origin')
            $res.Headers.Add('Cache-Control', 'no-cache')
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        }
    } catch {
        try { $res.StatusCode = 500 } catch {}
    } finally {
        $res.Close()
    }
}
