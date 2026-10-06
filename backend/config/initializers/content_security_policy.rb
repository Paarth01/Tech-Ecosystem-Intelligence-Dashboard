# Strict policy for the React app: only our own scripts may run, which also limits what an
# injected script could do. It is attached to every file served from public/ and to deep links.
csp = [
  "default-src 'self'", "script-src 'self'", "style-src 'self'", "style-src-attr 'unsafe-inline'",
  "img-src 'self' data:", "connect-src 'self'", "base-uri 'self'", "form-action 'self'",
  "frame-ancestors 'none'"
].join("; ")

Rails.application.config.x.csp = csp
Rails.application.config.public_file_server.headers = {
  "Content-Security-Policy" => csp,
  "X-Content-Type-Options" => "nosniff",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=()"
}
