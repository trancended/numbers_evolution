defmodule NumbersEvolution.Simulations.SimulationDuplicateController do
  @moduledoc """
  Kontroler zapobiegający duplikatom prób w pojedynczej symulacji.

  Używa ETS do efektywnego sprawdzania unikalności kombinacji.
  Każda symulacja ma własną tabelę ETS, co zapewnia izolację między symulacjami.
  """

  defstruct [:table_name, :duplicates_count]

  @type t :: %__MODULE__{
          table_name: atom(),
          duplicates_count: non_neg_integer()
        }

  @doc """
  Tworzy nowy kontroler duplikatów dla symulacji.
  """
  @spec new() :: t()
  def new do
    # Utwórz unikalną nazwę tabeli ETS dla tej symulacji
    table_name = :"duplicate_check_#{:erlang.unique_integer([:positive])}"

    # Utwórz tabelę ETS typu set (bez duplikatów)
    :ets.new(table_name, [:set, :public, :named_table])

    %__MODULE__{
      table_name: table_name,
      duplicates_count: 0
    }
  end

  @doc """
  Sprawdza czy próba jest duplikatem i aktualizuje stan kontrolera.

  Returns:
  - `{:unique, controller}` - próba jest unikalna, kontroler zawiera nową kombinację
  - `{:duplicate, controller}` - próba jest duplikatem, licznik duplikatów został zwiększony

  ## Examples

      iex> controller = SimulationDuplicateController.new()
      iex> attempt = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      iex> {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      iex> {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt)

  """
  @spec check_attempt(t(), %{main: list(), euro: list()}) :: {:unique | :duplicate, t()}
  def check_attempt(%__MODULE__{} = controller, %{main: main, euro: euro}) do
    # Generuj hash kombinacji dla efektywnego porównania
    combination_hash = generate_combination_hash(main, euro)

    # Sprawdź czy hash już istnieje w tabeli ETS
    case :ets.lookup(controller.table_name, combination_hash) do
      [] ->
        # Unikalna próba - dodajemy do tabeli ETS
        :ets.insert(controller.table_name, {combination_hash, true})
        {:unique, controller}

      [_] ->
        # Duplikat - zwiększamy licznik
        {:duplicate,
         %__MODULE__{
           controller
           | duplicates_count: controller.duplicates_count + 1
         }}
    end
  end

  @doc """
  Generuje hash kombinacji dla efektywnego porównania.

  Sortuje liczby aby zapewnić deterministyczny hash niezależny od kolejności.

  ## Examples

      iex> SimulationDuplicateController.generate_combination_hash([1, 7, 23, 34, 50], [3, 9])
      "a1b2c3d4e5f6..."

      iex> SimulationDuplicateController.generate_combination_hash([34, 1, 50, 23, 7], [9, 3])
      "a1b2c3d4e5f6..." # taki sam hash dla tych samych liczb

  """
  @spec generate_combination_hash(list(), list()) :: String.t()
  def generate_combination_hash(main_numbers, euro_numbers)
      when is_list(main_numbers) and is_list(euro_numbers) do
    # Sortujemy liczby dla deterministycznego hasha
    sorted_main = Enum.sort(main_numbers)
    sorted_euro = Enum.sort(euro_numbers)

    # Tworzymy string reprezentację
    main_str = Enum.join(sorted_main, ",")
    euro_str = Enum.join(sorted_euro, ",")

    # Generujemy hash
    :crypto.hash(:md5, "#{main_str}|#{euro_str}")
    |> Base.encode16(case: :lower)
  end

  @doc """
  Zwraca statystyki duplikatów dla podsumowania symulacji.

  ## Examples

      iex> controller = %SimulationDuplicateController{duplicates_count: 5}
      iex> SimulationDuplicateController.get_stats(controller)
      %{duplicates_skipped: 5}

  """
  @spec get_stats(t()) :: %{duplicates_skipped: non_neg_integer()}
  def get_stats(%__MODULE__{duplicates_count: count}) do
    %{duplicates_skipped: count}
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
  def get_detailed_stats(%__MODULE__{
        table_name: table_name,
        duplicates_count: duplicates_count
      }) do
    unique_attempts = :ets.info(table_name, :size)
    total_attempts = unique_attempts + duplicates_count
    duplicate_ratio = if unique_attempts > 0, do: duplicates_count / unique_attempts, else: 0.0

    %{
      duplicates_skipped: duplicates_count,
      unique_attempts: unique_attempts,
      total_attempts: total_attempts,
      duplicate_ratio: duplicate_ratio
    }
  end
end
