defmodule Kontor.Cache do
  @moduledoc """
  ETS-backed cache for scoring rules and skill trigger patterns.
  Avoids LLM calls for repeat email patterns (newsletters, automated notifications).
  The LLM creates the rule once; Elixir applies it mechanically.
  """

  use GenServer

  @scoring_rules_table :kontor_scoring_rules
  @skill_triggers_table :kontor_skill_triggers

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(@scoring_rules_table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@skill_triggers_table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end

  def get_scoring_rule(key) do
    case :ets.lookup(@scoring_rules_table, key) do
      [{^key, rule}] -> {:ok, rule}
      [] -> :miss
    end
  end

  def put_scoring_rule(key, rule) do
    :ets.insert(@scoring_rules_table, {key, rule})
    :ok
  end

  def get_skill_triggers do
    :ets.tab2list(@skill_triggers_table)
  end

  def put_skill_trigger(skill_id, trigger_config) do
    :ets.insert(@skill_triggers_table, {skill_id, trigger_config})
    :ok
  end

  def delete_skill_trigger(skill_id) do
    :ets.delete(@skill_triggers_table, skill_id)
    :ok
  end

  def clear_scoring_rules do
    :ets.delete_all_objects(@scoring_rules_table)
    :ok
  end
end
