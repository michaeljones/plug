import gleam/bytes_builder.{type BytesBuilder}
import gleam/dynamic.{type Dynamic}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/option.{type Option, None, Some}
import gleam/result

pub type Conn

@external(erlang, "Elixir.GleamPlug", "port")
pub fn port(conn: Conn) -> Int

@external(erlang, "Elixir.GleamPlug", "host")
pub fn host(conn: Conn) -> String

@external(erlang, "Elixir.GleamPlug", "scheme")
pub fn scheme(conn: Conn) -> http.Scheme

@external(erlang, "Elixir.GleamPlug", "method")
fn elixir_method(conn: Conn) -> Dynamic

pub fn method(conn: Conn) -> http.Method {
  conn
  |> elixir_method
  |> http.method_from_dynamic
  |> result.unwrap(http.Get)
}

@external(erlang, "Elixir.GleamPlug", "request_path")
pub fn request_path(conn: Conn) -> String

@external(erlang, "Elixir.GleamPlug", "req_headers")
pub fn req_headers(conn: Conn) -> List(http.Header)

@external(erlang, "Elixir.GleamPlug", "query_string")
fn elixir_query_string(conn: Conn) -> String

pub fn query_string(conn: Conn) -> Option(String) {
  case elixir_query_string(conn) {
    "" -> None
    q -> Some(q)
  }
}

/// Convert a Plug connection to a Gleam HTTP request which can be
/// used to call a Gleam HTTP service.
///
/// It is common Plug applications to extract and decode the request
/// body using a middleware so this function does not attempt to read
/// the body directly from the conn, instead it must be given as the
/// second argument.
///
pub fn conn_to_request(conn: Conn) -> request.Request(a) {
  request.Request(
    body: body,
    headers: req_headers(conn),
    host: host(conn),
    path: request_path(conn),
    method: method(conn),
    port: Some(port(conn)),
    query: query_string(conn),
    scheme: scheme(conn),
  )
}

@external(erlang, "Elixir.Plug.Conn", "send_resp")
fn send_resp(conn: Conn, status: Int, body: BytesBuilder) -> Conn

@external(erlang, "Elixir.Plug.Conn", "merge_resp_headers")
fn merge_resp_headers(conn: Conn, headers: List(http.Header)) -> Conn

/// Send a Gleam HTTP response over the Plug connection.
///
/// Note that this function does not halt the connection, so if subsequent
/// plugs try to send another response, it will error out. Use the `halt`
/// function after this function if you want to halt the plug pipeline.
///
pub fn send(response: response.Response(BytesBuilder), conn: Conn) -> Conn {
  conn
  |> merge_resp_headers(response.headers)
  |> send_resp(response.status, response.body)
}

/// Halts the Plug pipeline by preventing further plugs downstream from being
/// invoked. See the docs for Plug.Builder for more information on halting a
/// Plug pipeline.
///
@external(erlang, "Elixir.Plug.Conn", "halt")
pub fn halt(conn: Conn) -> Conn
