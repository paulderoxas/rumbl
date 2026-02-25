defmodule RumblWeb.Router do
  use RumblWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {RumblWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(RumblWeb.Auth)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", RumblWeb do
    pipe_through(:browser)

    get("/", PageController, :home)

    # use LiveView for the login form
    get("/sessions/callback", SessionController, :create_from_live)
    live("/sessions/new", SessionLive.New)

    # Users
    live("/users", UserLive.Index)
    live("/users/new", UserLive.New)
    live("/users/:id", UserLive.Show)

    # Videos (all protected by auth check inside each LiveView's mount)
    live("/videos", VideoLive.Index)
    live("/videos/new", VideoLive.New)
    live("/videos/:id", VideoLive.Show)
    live("/videos/:id/edit", VideoLive.Edit)

    # Watch (public — auth check is optional inside mount)
    live("/watch/:id", VideoLive.Watch)

    # Keep the logout as a controller since it needs to drop the session
    delete("/sessions", SessionController, :delete)
  end

  # Other scopes may use custom stacks.
  # scope "/api", RumblWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rumbl, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: RumblWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
