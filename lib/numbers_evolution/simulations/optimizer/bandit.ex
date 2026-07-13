defmodule NumbersEvolution.Simulations.Optimizer.Bandit do
  @moduledoc """
  ALG-8 — Thompson-sampling portfolio bandit: the **mixing engine**.

  Treats each candidate algorithm (or parameterization) as an "arm" and
  adaptively allocates the attempt budget toward the arms with the best observed
  reward (e.g. normalized hit-rate or EV). Uses a Beta–Bernoulli posterior per
  arm; `select/1` samples each posterior and pulls the current best draw, so
  exploration and exploitation balance themselves — no schedule to tune.

  Rewards are expected in `0.0..1.0` (normalize hit-rate / EV before feeding).
  Reproducible via a seeded process RNG.

      state = Bandit.new([:standard, :vip2, :annealing])
      arm   = Bandit.select(state)
      state = Bandit.reward(state, arm, 0.7)
      Bandit.best(state)
  """

  @type arm :: term()
  @type state :: %{arms: %{arm() => {float(), float()}}}

  @doc "New portfolio over `arms` with a uniform Beta(1,1) prior each."
  @spec new([arm()]) :: state()
  def new(arms) when is_list(arms) and arms != [] do
    %{arms: Map.new(arms, fn a -> {a, {1.0, 1.0}} end)}
  end

  @doc "Sample each arm's posterior and return the arm with the highest draw."
  @spec select(state()) :: arm()
  def select(%{arms: arms}) do
    {arm, _sample} =
      arms
      |> Enum.map(fn {a, {alpha, beta}} -> {a, sample_beta(alpha, beta)} end)
      |> Enum.max_by(fn {_a, sample} -> sample end)

    arm
  end

  @doc "Update an arm's posterior with a reward in `0.0..1.0`."
  @spec reward(state(), arm(), number()) :: state()
  def reward(%{arms: arms} = state, arm, r) do
    r = r |> max(0.0) |> min(1.0)
    {alpha, beta} = Map.fetch!(arms, arm)
    %{state | arms: Map.put(arms, arm, {alpha + r, beta + (1.0 - r)})}
  end

  @doc "Arm with the highest posterior mean (the current exploitation choice)."
  @spec best(state()) :: arm()
  def best(%{arms: arms}) do
    {arm, _mean} =
      arms
      |> Enum.map(fn {a, {alpha, beta}} -> {a, alpha / (alpha + beta)} end)
      |> Enum.max_by(fn {_a, mean} -> mean end)

    arm
  end

  @doc "Per-arm summary: posterior mean and effective pull count."
  @spec stats(state()) :: %{arm() => %{mean: float(), pulls: float()}}
  def stats(%{arms: arms}) do
    Map.new(arms, fn {a, {alpha, beta}} ->
      {a, %{mean: alpha / (alpha + beta), pulls: alpha + beta - 2.0}}
    end)
  end

  # Beta(a, b) via two Gamma draws: X/(X+Y), X~Gamma(a), Y~Gamma(b).
  defp sample_beta(a, b) do
    x = sample_gamma(a)
    y = sample_gamma(b)
    if x + y == 0.0, do: 0.5, else: x / (x + y)
  end

  # Marsaglia–Tsang gamma sampler (valid for shape >= 1, which always holds here
  # since posteriors start at 1.0 and only grow).
  defp sample_gamma(shape) do
    d = shape - 1.0 / 3.0
    c = 1.0 / :math.sqrt(9.0 * d)
    gamma_loop(d, c)
  end

  defp gamma_loop(d, c) do
    x = gaussian()
    v = :math.pow(1.0 + c * x, 3)
    if v > 0.0 and accept?(x, v, d), do: d * v, else: gamma_loop(d, c)
  end

  defp accept?(x, v, d) do
    u = :rand.uniform()
    u < 1.0 - 0.0331 * x * x * x * x or :math.log(u) < 0.5 * x * x + d * (1.0 - v + :math.log(v))
  end

  defp gaussian do
    u1 = max(:rand.uniform(), 1.0e-12)
    u2 = :rand.uniform()
    :math.sqrt(-2.0 * :math.log(u1)) * :math.cos(2.0 * :math.pi() * u2)
  end
end
