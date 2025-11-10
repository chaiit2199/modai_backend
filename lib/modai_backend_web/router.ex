defmodule ModaiBackendWeb.Router do
  use ModaiBackendWeb, :router

  pipeline :api do
    plug ModaiBackendWeb.Plugs.CORS
    plug :accepts, ["json"]
  end

  scope "/api", ModaiBackendWeb do
    pipe_through :api

    post "/login", AuthController, :login
    post "/register", AuthController, :register
    post "/forgot-password", AuthController, :forgot_password
    post "/reset-password", AuthController, :reset_password
    post "/refresh-token", AuthController, :refresh_token

    # DailyBloc API
    get "/posts/latest", DailyBlocController, :latest_posts
    get "/posts", DailyBlocController, :all_posts
    get "/posts/:id", DailyBlocController, :post_details
    post "/posts/create", DailyBlocController, :create_post
    put "/posts/update/:id", DailyBlocController, :update_post
    delete "/posts/delete/:id", DailyBlocController, :delete_post
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:modai_backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ModaiBackendWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
