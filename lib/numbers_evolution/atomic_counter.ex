defmodule NumbersEvolution.AtomicCounter do
  @moduledoc """
  ETS-based atomic counter for high-performance concurrent updates.
  Much faster than GenServer-based counter as it avoids message passing overhead.
  """

  @doc """
  Creates a new ETS table for atomic counter operations.
  Returns the table reference.
  """
  def new(initial_value \\ 0) do
    table_name = :"atomic_counter_#{:erlang.unique_integer([:positive])}"
    :ets.new(table_name, [:set, :public, :named_table])
    :ets.insert(table_name, {:count, initial_value})
    table_name
  end

  @doc """
  Atomically increments the counter and returns the new value.
  This is thread-safe and much faster than GenServer.call.
  """
  def increment(table_name) do
    :ets.update_counter(table_name, :count, 1)
  end

  @doc """
  Gets the current counter value.
  """
  def get(table_name) do
    case :ets.lookup(table_name, :count) do
      [{:count, value}] -> value
      [] -> 0
    end
  end

  @doc """
  Deletes the ETS table to free memory.
  """
  def delete(table_name) do
    :ets.delete(table_name)
  end
end
