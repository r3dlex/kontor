defmodule Kontor.AI.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Kontor.AI.Sandbox,
      Kontor.AI.SkillLoader,
      Kontor.AI.Embeddings,
      Kontor.AI.Pipeline
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
