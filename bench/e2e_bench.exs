# End-to-end per-attempt pipeline benchmark (generate -> dedup -> prize tiers),
# single-threaded, plus a task-coordination overhead comparison:
#
#     mix run --no-start bench/e2e_bench.exs
#
# Baseline (2026-06-11, before Phase 1 optimizations):
#   pipeline: standard              200000 attempts in 3882.4 ms ->  51514 attempts/sec
#   pipeline: vip2                  200000 attempts in 1738.1 ms -> 115069 attempts/sec
#   coordination: task-per-attempt   20000 attempts in  386.3 ms ->  51778 attempts/sec
#   coordination: plain loop         20000 attempts in  387.6 ms ->  51602 attempts/sec
# Conclusion: per-attempt Task spawn overhead is negligible on BEAM; the per-attempt
# pipeline cost (generator above all) dominates.
#
# After Phase 1 (2026-06-11):
#   pipeline: standard              200000 attempts in 2787.9 ms ->  71737 attempts/sec (+39%)
#   pipeline: vip2                  200000 attempts in 1100.4 ms -> 181757 attempts/sec (+58%)
# Plus, not visible here: successful simulations no longer pay a fixed
# Process.sleep(500) and per-round Logger.info with full tier-map inspects.

Code.require_file("support.exs", __DIR__)

alias NumbersEvolution.Simulations
alias NumbersEvolution.Simulations.SimulationDuplicateController
alias NumbersEvolution.Strategies.Generator

defmodule Bench.E2E do
  @attempts 200_000

  # Copy of Simulations.calculate_all_prize_tiers/2 + count_matches/2 as of Phase 0
  # (the real function is private). Once a public version exists it is used instead.
  @prize_tiers %{
    {5, 2} => 1,
    {5, 1} => 2,
    {5, 0} => 3,
    {4, 2} => 4,
    {4, 1} => 5,
    {3, 2} => 6,
    {4, 0} => 7,
    {2, 2} => 8,
    {3, 1} => 9,
    {3, 0} => 10,
    {1, 2} => 11,
    {2, 1} => 12
  }

  def tiers_fun do
    if function_exported?(Simulations, :calculate_all_prize_tiers, 2) do
      &Simulations.calculate_all_prize_tiers/2
    else
      &baseline_tiers/2
    end
  end

  def baseline_tiers(generated, target_numbers) do
    main_matches = count_matches(generated.main, target_numbers.main_numbers)
    euro_matches = count_matches(generated.euro, target_numbers.euro_numbers)

    for main <- 1..main_matches,
        euro <- 0..euro_matches,
        tier = Map.get(@prize_tiers, {main, euro}),
        tier != nil do
      tier
    end
    |> Enum.sort()
  end

  defp count_matches(generated_list, target_list) do
    generated_set = MapSet.new(generated_list)
    target_set = MapSet.new(target_list)
    MapSet.intersection(generated_set, target_set) |> MapSet.size()
  end

  def run_pipeline(label, strategy, generator_opts, target) do
    controller = SimulationDuplicateController.new()
    tiers = tiers_fun()

    {us, _} =
      :timer.tc(fn ->
        Enum.each(1..@attempts, fn _ ->
          case Generator.generate_numbers(strategy, generator_opts) do
            {:ok, generated} ->
              SimulationDuplicateController.check_attempt(controller, %{
                main: generated.main,
                euro: generated.euro
              })

              tiers.(generated, target)

            {:error, _} ->
              :ok
          end
        end)
      end)

    report(label, @attempts, us)
  end

  # Quantifies the cost of one-Task-per-attempt coordination (current architecture)
  # vs a plain loop doing the same work.
  def run_task_overhead(strategy, target) do
    attempts = 20_000
    thread_count = 10
    tiers = tiers_fun()

    work = fn controller ->
      case Generator.generate_numbers(strategy, []) do
        {:ok, generated} ->
          SimulationDuplicateController.check_attempt(controller, %{
            main: generated.main,
            euro: generated.euro
          })

          tiers.(generated, target)

        {:error, _} ->
          :ok
      end
    end

    controller1 = SimulationDuplicateController.new()

    {us_tasks, _} =
      :timer.tc(fn ->
        Enum.each(1..div(attempts, thread_count), fn _ ->
          1..thread_count
          |> Enum.map(fn _ -> Task.async(fn -> work.(controller1) end) end)
          |> Task.yield_many(5000)
        end)
      end)

    controller2 = SimulationDuplicateController.new()

    {us_loop, _} =
      :timer.tc(fn ->
        Enum.each(1..attempts, fn _ -> work.(controller2) end)
      end)

    report("coordination: task-per-attempt", attempts, us_tasks)
    report("coordination: plain loop     ", attempts, us_loop)
  end

  defp report(label, attempts, us) do
    per_sec = round(attempts / (us / 1_000_000))
    ms = Float.round(us / 1000, 1)
    IO.puts("#{label}: #{attempts} attempts in #{ms} ms -> #{per_sec} attempts/sec")
  end
end

strategy = Bench.Support.standard_strategy()
target = Bench.Support.target_numbers()

# Mirror what run_simulation does since Phase 1.2: pools precomputed once
generator_opts =
  if function_exported?(Generator, :build_pools, 1) do
    [pools: Generator.build_pools(strategy)]
  else
    []
  end

vip2_blacklist = Bench.Support.vip2_blacklist()

vip2_blacklist =
  if function_exported?(Generator, :prepare_vip2_pools, 1) do
    Map.put(vip2_blacklist, :pools, Generator.prepare_vip2_pools(vip2_blacklist))
  else
    vip2_blacklist
  end

Bench.E2E.run_pipeline("pipeline: standard", strategy, generator_opts, target)
Bench.E2E.run_pipeline("pipeline: vip2    ", strategy, [vip2_blacklist: vip2_blacklist], target)

Bench.E2E.run_task_overhead(strategy, target)
