ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(NumbersEvolution.Repo, :manual)

# Configure Mox
Mox.defmock(NumbersEvolution.HTTPClientMock, for: NumbersEvolution.HTTPClient)
