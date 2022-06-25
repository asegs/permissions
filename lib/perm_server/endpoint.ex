defmodule PermServer.Endpoint do
  use Plug.Router
  use Plug.Debugger
  
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json, :urlencoded, :multipart],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(:dispatch)
  forward("/",to: PermServer.Router)

  match _ do
    send_resp(conn, 404, "Requested page not found!")
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts),
    do: Plug.Cowboy.http(__MODULE__, [])
end
