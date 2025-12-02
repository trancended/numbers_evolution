defmodule NumbersEvolutionWeb.NavigationComponents do
  @moduledoc """
  Navigation components for Numbers Evolution app.
  Handles desktop navbar, mobile drawer, and user menu.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents

  # Admin helper functions
  defp admin?(user) when is_nil(user), do: false

  defp admin?(user) do
    admin_user = Application.get_env(:numbers_evolution, :admin_user, "aa@aa.aa")
    user.email == admin_user
  end

  # ============================================================================
  # Main Navigation Component
  # ============================================================================

  @doc """
  Renders the main navigation bar (desktop) and drawer (mobile).
  """
  attr :active_section, :atom, required: true
  attr :current_user, :map, required: true

  def navbar(assigns) do
    ~H"""
    <%!-- Desktop Navbar (>768px) --%>
    <nav class="navbar bg-base-200 px-4 sm:px-6 lg:px-8 shadow-lg hidden md:flex">
      <div class="flex-1">
        <span class="text-xl font-bold">Numbers Evolution</span>
      </div>
      <div class="flex-none">
        <ul class="menu menu-horizontal px-1 gap-2">
          <.nav_item
            section={:dashboard}
            active={@active_section}
            icon="hero-home"
            label="Dashboard"
            data_cy="nav-dashboard"
          />
          <.nav_item
            section={:strategies}
            active={@active_section}
            icon="hero-light-bulb"
            label="Strategie"
            data_cy="nav-strategies"
          />
          <.nav_item
            section={:simulations}
            active={@active_section}
            icon="hero-chart-bar"
            label="Symulacje"
            data_cy="nav-simulations"
          />
          <.nav_item
            section={:ranking}
            active={@active_section}
            icon="hero-trophy"
            label="Ranking"
            data_cy="nav-ranking"
          />
          <.nav_item
            section={:generator}
            active={@active_section}
            icon="hero-sparkles"
            label="Generator"
            data_cy="nav-generator"
          />
          <%= if @current_user && admin?(@current_user) do %>
            <.nav_item
              section={:admin}
              active={@active_section}
              icon="hero-users"
              label="Użytkownicy"
              data_cy="nav-admin"
            />
          <% end %>
          <li>
            <.user_menu_dropdown current_user={@current_user} />
          </li>
        </ul>
      </div>
    </nav>

    <%!-- Mobile Drawer (≤768px) --%>
    <.mobile_drawer active_section={@active_section} current_user={@current_user} />
    """
  end

  # ============================================================================
  # Private Components
  # ============================================================================

  attr :section, :atom, required: true
  attr :active, :atom, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :data_cy, :string, default: nil

  defp nav_item(assigns) do
    ~H"""
    <li>
      <.link
        data-cy={@data_cy}
        navigate={get_path_for_section(@section)}
        class={["btn btn-ghost", @active == @section && "btn-active"]}
      >
        <.icon name={@icon} class="size-5 mr-2" /> {@label}
      </.link>
    </li>
    """
  end

  attr :current_user, :map, required: true

  defp user_menu_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <label data-cy="user-menu" tabindex="0" class="btn btn-ghost gap-2">
        <.icon name="hero-user-circle" class="size-5" />
        <span class="hidden sm:inline">{@current_user.email}</span>
      </label>
      <ul
        tabindex="0"
        class="dropdown-content menu p-2 shadow-lg bg-base-100 border border-base-300 rounded-box w-52 mt-2 z-50"
      >
        <li>
          <div class="px-3 py-2 text-sm text-base-content/70 border-b border-base-300">
            {@current_user.email}
          </div>
        </li>
        <li>
          <button
            data-cy="logout-button"
            phx-click="logout"
            class="w-full text-left px-3 py-2 hover:bg-base-200 rounded transition-colors text-base-content"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-4 inline mr-2" /> Wyloguj
          </button>
        </li>
      </ul>
    </div>
    """
  end

  attr :active_section, :atom, required: true
  attr :current_user, :map, required: true

  defp mobile_drawer(assigns) do
    ~H"""
    <div class="drawer md:hidden">
      <input id="mobile-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content">
        <nav class="navbar bg-base-200 px-4 shadow-lg">
          <div class="flex-1">
            <label for="mobile-drawer" class="btn btn-ghost btn-circle">
              <.icon name="hero-bars-3" class="size-6" />
            </label>
            <span class="ml-2 text-lg font-bold">Numbers Evolution</span>
          </div>
        </nav>
      </div>
      <div class="drawer-side z-50">
        <label for="mobile-drawer" class="drawer-overlay"></label>
        <ul class="menu p-4 w-80 min-h-full bg-base-200 gap-2">
          <li class="mb-4">
            <span class="text-xl font-bold">Numbers Evolution</span>
          </li>
          <.mobile_nav_item
            section={:dashboard}
            active={@active_section}
            icon="hero-home"
            label="Dashboard"
          />
          <.mobile_nav_item
            section={:strategies}
            active={@active_section}
            icon="hero-light-bulb"
            label="Strategie"
          />
          <.mobile_nav_item
            section={:simulations}
            active={@active_section}
            icon="hero-chart-bar"
            label="Symulacje"
          />
          <.mobile_nav_item
            section={:ranking}
            active={@active_section}
            icon="hero-trophy"
            label="Ranking"
          />
          <.mobile_nav_item
            section={:generator}
            active={@active_section}
            icon="hero-sparkles"
            label="Generator"
          />
          <li class="mt-auto">
            <div class="border-t border-base-300 pt-4">
              <p class="text-sm mb-2">{@current_user.email}</p>
              <button phx-click="logout" class="btn btn-error btn-sm w-full">Wyloguj</button>
            </div>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :section, :atom, required: true
  attr :active, :atom, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp mobile_nav_item(assigns) do
    ~H"""
    <li>
      <.link
        navigate={get_path_for_section(@section)}
        class={["btn btn-ghost justify-start", @active == @section && "btn-active"]}
      >
        <.icon name={@icon} class="size-5 mr-2" /> {@label}
      </.link>
    </li>
    """
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp get_path_for_section(:dashboard), do: "/dashboard"
  defp get_path_for_section(:strategies), do: "/strategies"
  defp get_path_for_section(:simulations), do: "/simulations"
  defp get_path_for_section(:ranking), do: "/ranking"
  defp get_path_for_section(:generator), do: "/generator"
  defp get_path_for_section(:admin), do: "/admin"
  defp get_path_for_section(_), do: "/dashboard"
end
