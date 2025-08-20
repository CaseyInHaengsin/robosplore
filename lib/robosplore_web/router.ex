defmodule RobosploreWeb.Router do
  use RobosploreWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RobosploreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RobosploreWeb do
    pipe_through :browser

    live "/", Home
    live "/host/:game_id", HostLive
    live "/play/:game_id/:player_id", PlayLive
    get "/join/:game_id", JoinController, :join
  end

  # Other scopes may use custom stacks.
  # scope "/api", RobosploreWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:robosplore, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RobosploreWeb.Telemetry
    end
  end
end
