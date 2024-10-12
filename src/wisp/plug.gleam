import directories
import gleam/bit_array
import gleam/bytes_builder.{type BytesBuilder}
import gleam/crypto
import gleam/dynamic.{type Dynamic}
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import wisp
import wisp/internal as wisp_internal

import wisp/plug/body as wisp_plug_body
import wisp/plug/conn.{type Conn} as _

@external(erlang, "Elixir.WispPlug", "port")
pub fn port(conn: Conn) -> Int

@external(erlang, "Elixir.WispPlug", "host")
pub fn host(conn: Conn) -> String

@external(erlang, "Elixir.WispPlug", "scheme")
pub fn scheme(conn: Conn) -> http.Scheme

@external(erlang, "Elixir.WispPlug", "method")
fn elixir_method(conn: Conn) -> Dynamic

pub fn method(conn: Conn) -> http.Method {
  conn
  |> elixir_method
  |> http.method_from_dynamic
  |> result.unwrap(http.Get)
}

@external(erlang, "Elixir.WispPlug", "request_path")
pub fn request_path(conn: Conn) -> String

@external(erlang, "Elixir.WispPlug", "req_headers")
pub fn req_headers(conn: Conn) -> List(http.Header)

@external(erlang, "Elixir.WispPlug", "query_string")
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
pub fn conn_to_request(
  conn: Conn,
  max_body_size: Int,
  max_files_size: Int,
  read_chunk_size: Int,
  base_temporary_directory: String,
  secret_key_base: String,
) -> wisp.Request {
  let temporary_directory = join_path(base_temporary_directory, random_slug())
  request.Request(
    headers: req_headers(conn),
    host: host(conn),
    path: request_path(conn),
    method: method(conn),
    port: Some(port(conn)),
    query: query_string(conn),
    scheme: scheme(conn),
    body: wisp_internal.Connection(
      reader: create_body_reader(conn),
      max_body_size:,
      max_files_size:,
      read_chunk_size:,
      temporary_directory:,
      secret_key_base:,
    ),
  )
}

fn create_body_reader(conn: Conn) -> wisp_internal.Reader {
  fn(length: Int) -> Result(wisp_internal.Read, Nil) {
    case wisp_plug_body.read(conn, length) {
      wisp_plug_body.Ok(body, conn) ->
        case bit_array.byte_size(body) {
          0 -> Ok(wisp_internal.ReadingFinished)
          _ -> Ok(wisp_internal.Chunk(body, next: create_body_reader(conn)))
        }
      wisp_plug_body.More(partial_body, conn) ->
        Ok(wisp_internal.Chunk(partial_body, next: create_body_reader(conn)))
      wisp_plug_body.Error(_reason) -> Error(Nil)
    }
  }
}

fn join_path(a: String, b: String) -> String {
  let b = remove_preceeding_slashes(b)
  case string.ends_with(a, "/") {
    True -> a <> b
    False -> a <> "/" <> b
  }
}

fn remove_preceeding_slashes(string: String) -> String {
  case string {
    "/" <> rest -> remove_preceeding_slashes(rest)
    _ -> string
  }
}

fn random_string(length: Int) -> String {
  crypto.strong_random_bytes(length)
  |> bit_array.base64_url_encode(False)
  |> string.slice(0, length)
}

fn random_slug() -> String {
  random_string(16)
}

pub fn tmp_dir() {
  case directories.tmp_dir() {
    Ok(tmp_dir) -> tmp_dir <> "/gleam-wisp/"
    Error(_) -> "./tmp/"
  }
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
pub fn send(response: wisp.Response, conn: Conn) -> Conn {
  let body = case response.body {
    wisp.Empty -> bytes_builder.new()
    wisp.Text(text) -> bytes_builder.from_string_builder(text)
    wisp.Bytes(bytes) -> bytes
    wisp.File(path) -> todo
  }

  conn
  |> merge_resp_headers(response.headers)
  |> send_resp(response.status, body)
}

/// Halts the Plug pipeline by preventing further plugs downstream from being
/// invoked. See the docs for Plug.Builder for more information on halting a
/// Plug pipeline.
///
@external(erlang, "Elixir.Plug.Conn", "halt")
pub fn halt(conn: Conn) -> Conn
