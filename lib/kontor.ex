defmodule Kontor do
  @moduledoc """
  Kontor — AI-driven email application.

  Single-tenant deployment with multi-tenant data model (tenant_id on all tables).
  """

  @doc """
  Returns the current tenant_id. For v1 single-tenant, always returns the
  configured default tenant.
  """
  def tenant_id do
    Application.get_env(:kontor, :tenant_id, "default")
  end
end
