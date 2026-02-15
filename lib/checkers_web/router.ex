defmodule CheckersWeb.Router do
  use CheckersWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CheckersWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CheckersWeb do
    pipe_through [:browser, :ensure_player_token]

    get "/", PageController, :home
    live "/game", GameLive
  end

  defp ensure_player_token(conn, _opts) do
    if get_session(conn, :player_token) do
      conn
    else
      token = Base.encode64(:crypto.strong_rand_bytes(16))
      put_session(conn, :player_token, token)
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", CheckersWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:checkers, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CheckersWeb.Telemetry
    end
  end
end
