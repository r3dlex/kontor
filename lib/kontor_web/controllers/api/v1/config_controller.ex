defmodule KontorWeb.API.V1.ConfigController do
  use KontorWeb, :controller

  def show(conn, _params) do
    config = %{
      ui_theme: "system",
      dark_light_mode: "system",
      mail_polling_frequency: Application.get_env(:kontor, :mail)[:default_polling_interval_seconds],
      font_size: "14px",
      font_type: "system",
      task_age_cutoff: Application.get_env(:kontor, :mail)[:default_task_age_cutoff_months],
      auto_confirm_threshold_high: Application.get_env(:kontor, :tasks)[:auto_confirm_threshold_high],
      auto_confirm_threshold_low: Application.get_env(:kontor, :tasks)[:auto_confirm_threshold_low],
      llm_throttle_emails_per_second: Application.get_env(:kontor, :mail)[:import_throttle_emails_per_second]
    }

    json(conn, %{config: config})
  end

  def update(conn, params) do
    # v1: config is stored in user preferences markdown; this is a stub
    json(conn, %{config: params, status: "updated"})
  end
end
