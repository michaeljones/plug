import gleam/bytes_builder.{type BytesBuilder}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/option.{None, Some}

pub fn handle(req: request.Request(BytesBuilder)) {
  let port = case req.port {
    Some(p) -> int.to_string(p)
    None -> "<none>"
  }
  response.new(200)
  |> response.prepend_header("made-with", "Gleam")
  |> response.prepend_header("got-path", req.path)
  |> response.prepend_header("got-method", http.method_to_string(req.method))
  |> response.prepend_header("got-scheme", http.scheme_to_string(req.scheme))
  |> response.prepend_header("got-port", port)
  |> response.prepend_header("got-host", req.host)
  |> response.set_body(req.body)
}
