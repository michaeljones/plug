defmodule WispPlug do
  @moduledoc """
  A Gleam HTTP adapter for the Plug web application interface.

  ## Examples

  Define a Gleam HTTP service

      import gleam/http
      import gleam/bit_builder.{BitBuilder}

      pub fn service(req: http.Request(BitBuilder)) {
        http.response(200)
        |> http.prepend_resp_header("made-with", "Gleam")
        |> http.set_resp_body(req.body)
      }

  And then call it from an Elixir Plug application

      defmodule MyPlug do
        def init(options) do
          options
        end

        def call(conn, params) do
          conn
          |> WispPlug.call_service(params, &:my_gleam_module.service/1)
        end
      end
  """

  @type headers :: [{String.t(), String.t()}]
  @type option(inner) :: :none | {:some, inner}
  @type port_number :: option(integer())
  @type query :: option(String.t())
  @type path :: String.t()
  @type scheme :: :http | :https
  @type method ::
          :get
          | :post
          | :head
          | :put
          | :delete
          | :trace
          | :connect
          | :options
          | :patch
          | {:other, String.t()}

  @type request(body) ::
          {:request, method(), headers(), body, scheme(), path(), port_number(), path(), query}

  @type response(body) :: {:response, integer(), headers(), body}

  
  def init(options) do
    handler = Keyword.fetch!(options, :handler)
    max_body_size = Keyword.get(options, :max_body_size, 8_000_000)
    max_files_size = Keyword.get(options, :max_files_size, 32_000_000)
    read_chunk_size = Keyword.get(options, :read_chunk_size, 1_000_000)
    base_temporary_directory = Keyword.get_lazy(options, :base_temporary_directory, &:wisp@plug.tmp_dir/0)
    secret_key_base = Keyword.fetch!(options, :secret_key_base)

    %{
      handler: handler,
      max_body_size: max_body_size,
      max_files_size: max_files_size,
      read_chunk_size: read_chunk_size,
      base_temporary_directory: base_temporary_directory,
      secret_key_base: secret_key_base,
    }
  end

  def call(conn, options) do
    handled = 
    conn_to_request(
      conn,
      options.max_body_size,
      options.max_files_size,
      options.read_chunk_size,
      options.base_temporary_directory,
      options.secret_key_base
    )
    # Send IO.inspect through as the logging function as believe that 
    # gleam struggle to log from an elixir set up
    |> options.handler.(&IO.inspect/1)

    case handled do
      {:some, response} -> send_response(response, conn)
      :none -> conn
    end
  end

  @doc """
  Convert a Plug connection to a Gleam HTTP request which can be
  used to call a Gleam HTTP service.

  It is common Plug applications to extract and decode the request
  body using a middleware so this function does not attempt to read
  the body directly from the conn, instead it must be given as the
  second argument.
  """
  def conn_to_request(
    conn,
    max_body_size,
    max_files_size,
    read_chunk_size,
    base_temporary_directory,
    secret_key_base
    ) do
    :wisp@plug.conn_to_request(
      conn,
      max_body_size,
      max_files_size,
      read_chunk_size,
      base_temporary_directory,
      secret_key_base
    )
  end

  @doc """
  Send a Gleam HTTP response over the Plug connection.

  Note that this function does not halt the connection, so if subsequent
  plugs try to send another response, it will error out. Use `Plug.Conn.halt/1!`
  after this function if you want to halt the plug pipeline.
  """
  def send_response(response, conn) do
    :wisp@plug.send(response, conn)
  end

  @doc false
  def port(conn), do: conn.port
  @doc false
  def host(conn), do: conn.host
  @doc false
  def scheme(conn), do: conn.scheme
  @doc false
  def method(conn), do: conn.method
  @doc false
  def request_path(conn), do: conn.request_path
  @doc false
  def req_headers(conn), do: conn.req_headers
  @doc false
  def query_string(conn), do: conn.query_string
end

