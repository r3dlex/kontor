defmodule KontorWeb.ErrorJSON do
  def render("404.json", _), do: %{errors: %{detail: "Not Found"}}
  def render("500.json", _), do: %{errors: %{detail: "Internal Server Error"}}

  def render(template, _) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
