defmodule PermServer.Endpoint do
  use Plug.Router
  use Plug.Debugger
  plug Corsica, origins: "http://localhost:3000", allow_headers: :all
  
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json, :urlencoded, :multipart],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(:dispatch)
  forward("/",to: PermServer.Router)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts),
    do: Plug.Cowboy.http(__MODULE__, [])
end
