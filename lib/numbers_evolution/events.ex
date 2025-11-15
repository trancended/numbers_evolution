defmodule NumbersEvolution.Events do
  @moduledoc """
  The Events context.

  Handles logging of user events and analytics tracking.
  """

  import Ecto.Query, warn: false
  alias NumbersEvolution.Events.Event
  alias NumbersEvolution.Repo

  @doc """
  Logs an event for a user.

  ## Examples

      iex> log_event(user_id, :strategy_created, %{entity_id: "..."})
      {:ok, %Event{}}

      iex> log_event(user_id, :invalid_type, %{})
      {:error, %Ecto.Changeset{}}

  """
  @spec log_event(binary(), atom(), map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def log_event(user_id, event_type, metadata \\ %{}) do
    %Event{}
    |> Event.changeset(%{
      user_id: user_id,
      event_type: event_type,
      metadata: metadata
    })
    |> Repo.insert()
  end

  @doc """
  Gets events for a user.

  ## Options

    * `:event_type` - Filter by event type
    * `:from_date` - Get events from this date
    * `:to_date` - Get events until this date
    * `:limit` - Maximum number of events to return

  ## Examples

      iex> list_events(user_id)
      [%Event{}, ...]

      iex> list_events(user_id, event_type: :ai_success, limit: 10)
      [%Event{}, ...]

  """
  @spec list_events(binary(), keyword()) :: [Event.t()]
  def list_events(user_id, opts \\ []) do
    from(e in Event, where: e.user_id == ^user_id)
    |> filter_by_event_type(opts[:event_type])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> order_by([e], desc: e.inserted_at)
    |> limit_events(opts[:limit])
    |> Repo.all()
  end

  @doc """
  Counts events for a user.

  ## Examples

      iex> count_events(user_id)
      42

      iex> count_events(user_id, event_type: :simulation_completed)
      15

  """
  @spec count_events(binary(), keyword()) :: non_neg_integer()
  def count_events(user_id, opts \\ []) do
    from(e in Event, where: e.user_id == ^user_id)
    |> filter_by_event_type(opts[:event_type])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> Repo.aggregate(:count)
  end

  ## Private Helpers

  defp filter_by_event_type(query, nil), do: query

  defp filter_by_event_type(query, event_type) when is_atom(event_type) do
    from(e in query, where: e.event_type == ^event_type)
  end

  defp filter_by_event_type(query, _), do: query

  defp filter_by_date_range(query, nil, nil), do: query

  defp filter_by_date_range(query, from_date, nil) when not is_nil(from_date) do
    from(e in query, where: e.inserted_at >= ^from_date)
  end

  defp filter_by_date_range(query, nil, to_date) when not is_nil(to_date) do
    from(e in query, where: e.inserted_at <= ^to_date)
  end

  defp filter_by_date_range(query, from_date, to_date) do
    from(e in query,
      where: e.inserted_at >= ^from_date and e.inserted_at <= ^to_date
    )
  end

  defp limit_events(query, nil), do: query

  defp limit_events(query, limit) when is_integer(limit) and limit > 0 do
    from(e in query, limit: ^limit)
  end

  defp limit_events(query, _), do: query
end
