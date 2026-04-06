ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Kontor.Repo, :manual)

# Define Mox mocks for external dependencies
# These are referenced in test/support/mocks.ex and used in controller/channel tests.
Mox.defmock(Kontor.Auth.GoogleMock, for: Kontor.Auth.GoogleBehaviour)
Mox.defmock(Kontor.Auth.MicrosoftMock, for: Kontor.Auth.MicrosoftBehaviour)
Mox.defmock(Kontor.Accounts.Mock, for: Kontor.Accounts.Behaviour)
Mox.defmock(Kontor.AI.MinimaxClientMock, for: Kontor.AI.MinimaxClientBehaviour)
