import gleam/dynamic.{type Dynamic}

import wisp/plug/conn.{type Conn} as _

pub type ReadOutput {
  Ok(BitArray, Conn)
  More(BitArray, Conn)
  Error(Dynamic)
}

pub fn read(conn: Conn, length: Int) -> ReadOutput {
  read_conn_body(conn, [Length(length)])
}

type Options {
  Length(Int)
}

@external(erlang, "Elixir.Plug.Conn", "read_body")
fn read_conn_body(conn: Conn, opts: List(Options)) -> ReadOutput
