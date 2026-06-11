defmodule NumbersEvolution.Simulations.SimulationDuplicateController do
  @moduledoc """
  Kontroler zapobiegający duplikatom prób w pojedynczej symulacji.

  Używa ETS do efektywnego sprawdzania unikalności kombinacji.
  Każda symulacja ma własną tabelę ETS, co zapewnia izolację między symulacjami.

  Licznik duplikatów jest trzymany w samej tabeli ETS (klucz `:dup_count`),
  dzięki czemu działa poprawnie przy równoległych próbach z wielu procesów —
  struktura kontrolera jest tylko uchwytem do tabeli.
  """

  defstruct [:table_name]

  @type t :: %__MODULE__{
          table_name: atom()
        }

  @dup_count_key :dup_count

  @doc """
  Tworzy nowy kontroler duplikatów dla symulacji.
  """
  @spec new() :: t()
  def new do
    # Utwórz unikalną nazwę tabeli ETS dla tej symulacji
    table_name = :"duplicate_check_#{:erlang.unique_integer([:positive])}"

    # Utwórz tabelę ETS typu set (bez duplikatów)
    :ets.new(table_name, [:set, :public, :named_table])
    :ets.insert(table_name, {@dup_count_key, 0})

    %__MODULE__{table_name: table_name}
  end

  @doc """
  Sprawdza czy próba jest duplikatem i aktualizuje licznik w tabeli ETS.

  Returns:
  - `{:unique, controller}` - próba jest unikalna, kombinacja została zapisana
  - `{:duplicate, controller}` - próba jest duplikatem, licznik duplikatów został zwiększony

  ## Examples

      iex> controller = SimulationDuplicateController.new()
      iex> attempt = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      iex> {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      iex> {:duplicate, _controller} = SimulationDuplicateController.check_attempt(controller, attempt)

  """
  @spec check_attempt(t(), %{main: list(), euro: list()}) :: {:unique | :duplicate, t()}
  def check_attempt(%__MODULE__{} = controller, %{main: main, euro: euro}) do
    combination_key = generate_combination_hash(main, euro)

    # insert_new jest atomowy - zwraca false gdy klucz już istnieje,
    # więc równoległe procesy nie zaliczą tej samej kombinacji dwukrotnie
    if :ets.insert_new(controller.table_name, {combination_key}) do
      {:unique, controller}
    else
      :ets.update_counter(controller.table_name, @dup_count_key, 1)
      {:duplicate, controller}
    end
  end

  @doc """
  Generuje klucz kombinacji dla efektywnego porównania.

  Sortuje liczby aby zapewnić deterministyczny klucz niezależny od kolejności.
  Krotka posortowanych liczb jest dokładna (zero kolizji) i znacznie tańsza
  niż hash kryptograficzny.

  ## Examples

      iex> SimulationDuplicateController.generate_combination_hash([1, 7, 23, 34, 50], [3, 9])
      {{1, 7, 23, 34, 50}, {3, 9}}

      iex> SimulationDuplicateController.generate_combination_hash([34, 1, 50, 23, 7], [9, 3])
      {{1, 7, 23, 34, 50}, {3, 9}}

  """
  @spec generate_combination_hash(list(), list()) :: {tuple(), tuple()}
  def generate_combination_hash(main_numbers, euro_numbers)
      when is_list(main_numbers) and is_list(euro_numbers) do
    {
      main_numbers |> Enum.sort() |> List.to_tuple(),
      euro_numbers |> Enum.sort() |> List.to_tuple()
    }
  end

  @doc """
  Zwraca statystyki duplikatów dla podsumowania symulacji.

  ## Examples

      iex> controller = SimulationDuplicateController.new()
      iex> attempt = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      iex> {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      iex> {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      iex> SimulationDuplicateController.get_stats(controller)
      %{duplicates_skipped: 1}

  """
  @spec get_stats(t()) :: %{duplicates_skipped: non_neg_integer()}
  def get_stats(%__MODULE__{table_name: table_name}) do
    %{duplicates_skipped: duplicates_count(table_name)}
  end

  @doc """
  Zwraca szczegółowe statystyki duplikatów dla analizy.

  ## Examples

      iex> controller = SimulationDuplicateController.new()
      iex> {:unique, controller} = SimulationDuplicateController.check_attempt(controller, %{main: [1,2,3,4,5], euro: [1,2]})
      iex> {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, %{main: [1,2,3,4,5], euro: [1,2]})
      iex> SimulationDuplicateController.get_detailed_stats(controller)
      %{
        duplicates_skipped: 1,
        unique_attempts: 1,
        total_attempts: 2,
        duplicate_ratio: 1.0
      }

  """
  @spec get_detailed_stats(t()) :: %{
          duplicates_skipped: non_neg_integer(),
          unique_attempts: non_neg_integer(),
          total_attempts: non_neg_integer(),
          duplicate_ratio: float()
        }
  def get_detailed_stats(%__MODULE__{table_name: table_name}) do
    duplicates_skipped = duplicates_count(table_name)
    # Rozmiar tabeli zawiera wpis licznika duplikatów
    unique_attempts = max(:ets.info(table_name, :size) - 1, 0)
    total_attempts = unique_attempts + duplicates_skipped

    duplicate_ratio =
      if unique_attempts > 0, do: duplicates_skipped / unique_attempts, else: 0.0

    %{
      duplicates_skipped: duplicates_skipped,
      unique_attempts: unique_attempts,
      total_attempts: total_attempts,
      duplicate_ratio: duplicate_ratio
    }
  end

  defp duplicates_count(table_name) do
    case :ets.lookup(table_name, @dup_count_key) do
      [{@dup_count_key, count}] -> count
      [] -> 0
    end
  end
end
