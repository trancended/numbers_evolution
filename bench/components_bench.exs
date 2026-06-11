# Component micro-benchmarks (no DB needed):
#
#     mix run --no-start bench/components_bench.exs
#
# Baseline (2026-06-11, before Phase 1 optimizations), Apple Silicon dev machine:
#   dedup: check (duplicate hit)      997.36 K ips    1.00 μs
#   dedup: check (mostly unique)      560.93 K ips    1.78 μs
#   generator: vip2                   160.54 K ips    6.23 μs
#   generator: half_random             90.86 K ips   11.01 μs
#   generator: standard                60.73 K ips   16.47 μs
#
# After Phase 1 (2026-06-11):
#   dedup: check (duplicate hit)               4787.97 K ips    0.21 μs  (4.8x)
#   dedup: check (mostly unique)               1489.30 K ips    0.67 μs  (2.7x)
#   generator: vip2 (precomputed pools)         245.06 K ips    4.08 μs  (1.5x)
#   generator: standard (precomputed pools)     86.88 K ips    11.51 μs  (1.4x)
#   generator: half_random                      98.13 K ips    10.19 μs  (unchanged path)

Code.require_file("support.exs", __DIR__)

{:ok, _} = Application.ensure_all_started(:benchee)

alias NumbersEvolution.Simulations.SimulationDuplicateController
alias NumbersEvolution.Strategies.Generator

strategy = Bench.Support.standard_strategy()
vip2_blacklist = Bench.Support.vip2_blacklist()

# Pre-filled dedup table (~100K unique combinations) to measure realistic lookups
controller = SimulationDuplicateController.new()

Enum.each(1..100_000, fn _ ->
  SimulationDuplicateController.check_attempt(controller, Bench.Support.random_attempt())
end)

duplicate_attempt = Bench.Support.random_attempt()
SimulationDuplicateController.check_attempt(controller, duplicate_attempt)

pools = Generator.build_pools(strategy)

vip2_blacklist_with_pools =
  Map.put(vip2_blacklist, :pools, Generator.prepare_vip2_pools(vip2_blacklist))

Benchee.run(
  %{
    "generator: standard" => fn -> Generator.generate_numbers(strategy) end,
    "generator: standard (precomputed pools)" => fn ->
      Generator.generate_numbers(strategy, pools: pools)
    end,
    "generator: half_random" => fn ->
      Generator.generate_numbers(strategy, half_random_mode: true)
    end,
    "generator: vip2" => fn ->
      Generator.generate_numbers(strategy, vip2_blacklist: vip2_blacklist)
    end,
    "generator: vip2 (precomputed pools)" => fn ->
      Generator.generate_numbers(strategy, vip2_blacklist: vip2_blacklist_with_pools)
    end,
    "dedup: check (mostly unique)" =>
      {fn attempt -> SimulationDuplicateController.check_attempt(controller, attempt) end,
       before_each: fn _ -> Bench.Support.random_attempt() end},
    "dedup: check (duplicate hit)" => fn ->
      SimulationDuplicateController.check_attempt(controller, duplicate_attempt)
    end
  },
  warmup: 1,
  time: 3
)
