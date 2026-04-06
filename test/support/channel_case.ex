defmodule KontorWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import KontorWeb.ChannelCase
      import Kontor.Factory

      # The default endpoint for testing
      @endpoint KontorWeb.Endpoint
    end
  end

  setup tags do
    Kontor.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Connects a socket with a valid JWT token for the given user and tenant.
  """
  defmacro connect_socket(user_id, tenant_id) do
    quote do
      {:ok, token} = KontorWeb.Auth.generate_token(unquote(user_id), unquote(tenant_id))
      {:ok, socket} = connect(KontorWeb.UserSocket, %{"token" => token}, %{})
      socket
    end
  end
end
