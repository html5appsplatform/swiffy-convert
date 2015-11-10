require! <[ fs request zlib stream ]>

function stream-to-buffer stream, callback
  bufs = []
  stream.on \data  -> bufs.push it
  stream.on \error -> callback it
  stream.on \end   -> callback null Buffer.concat bufs

module.exports = !function convert file, callback
  if file instanceof stream.Stream
    do
      err, buf <- stream-to-buffer file
      return callback? err if err
      convert buf, callback
    return void

  input = if typeof file is \string
          then fs.read-file-sync file
          else file
          |> (.to-string \base64)
          |> (.replace /\//g \_)
          |> (.replace /\+/g \-)

  err, res, body <~ request.post do
    url: 'https://www.googleapis.com/rpc?key=
          AIzaSyCC_WIu0oVvLtQGzv4-g7oaWNoc-u8JpEI'

    headers:
      Host: 'www.googleapis.com'
      'Cache-Control': \no-cache

    json:
      api-version: \v1
      method: 'swiffy.convertToHtml'
      params:
        client: 'Swiffy Flash Extension for Mac v1.1.1'
        input: input

  { status-code, status-message } = res
  return callback? err if err
  return callback? "[ #{status-code} ] #{status-message}" if status-code >= 400
  return callback? body.error.message if body.error?

  unless body.result.response.output?length
    return callback? body.result.response.status

  zip = body.result.response.output
        |> -> new Buffer it, \base64

  err, html <- zlib.gunzip zip
  html .= to-string!

  json = (.1) <| html is /swiffyobject\s*=\s*({.*});\s*<\/script>/
  
  width = (.1) <| html is /width:\s*([0-9]+)px/
  height = (.1) <| html is /height:\s*([0-9]+)px/

  callback? null body.result.response <<< output: {html, json, width, height}
