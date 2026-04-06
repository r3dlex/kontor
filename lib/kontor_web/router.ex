defmodule KontorWeb.Router do
  use KontorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug KontorWeb.Plugs.AuthenticateTenant
  end

  pipeline :public do
    plug :accepts, ["json"]
  end

  scope "/", KontorWeb do
    pipe_through :public
    get "/health", HealthController, :index
  end

  scope "/api/v1", KontorWeb.API.V1 do
    pipe_through :public
    post "/auth/google", AuthController, :google
    post "/auth/microsoft", AuthController, :microsoft
  end

  scope "/api/v1", KontorWeb.API.V1 do
    pipe_through :api

    get "/mailboxes", MailboxController, :index
    post "/mailboxes", MailboxController, :create
    get "/mailboxes/:id", MailboxController, :show
    put "/mailboxes/:id", MailboxController, :update
    delete "/mailboxes/:id", MailboxController, :delete

    get "/emails/:id", EmailController, :show
    get "/threads/:id", ThreadController, :show

    get "/tasks", TaskController, :index
    post "/tasks", TaskController, :create
    patch "/tasks/:id", TaskController, :update

    get "/calendar/today", CalendarController, :today
    get "/calendar/briefing/:event_id", CalendarController, :briefing
    post "/calendar/briefing/:event_id/refresh", CalendarController, :refresh_briefing

    get "/backoffice", BackOfficeController, :index

    get "/skills", SkillController, :index
    get "/skills/:id", SkillController, :show
    put "/skills/:id", SkillController, :update
    get "/skills/:id/versions", SkillController, :versions
    post "/skills/:id/revert", SkillController, :revert

    get "/profiles", ProfileController, :index
    put "/profiles/:id", ProfileController, :update

    post "/drafts", DraftController, :create
    post "/drafts/:id/send", DraftController, :send_draft

    get "/config", ConfigController, :show
    put "/config", ConfigController, :update

    get "/contacts", ContactController, :index
    get "/contacts/graph", ContactController, :graph
    get "/contacts/:id", ContactController, :show
    post "/contacts/:id/refresh", ContactController, :refresh

    get "/org-charts", OrgChartController, :index
    post "/org-charts", OrgChartController, :create
    put "/org-charts/:id", OrgChartController, :update

    patch "/threads/:id", ThreadController, :update
    delete "/tasks/:id", TaskController, :delete
    post "/calendar/events", CalendarController, :create_event
    patch "/calendar/events/:id", CalendarController, :update_event
    post "/skills/:id/execute", SkillController, :execute
    post "/profiles", ProfileController, :create
    get "/drafts", DraftController, :index

    get "/search", SearchController, :index

    post "/mcp/token", McpTokenController, :create
  end
end
