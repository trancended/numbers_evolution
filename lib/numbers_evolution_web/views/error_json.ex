defmodule NumbersEvolutionWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  @doc """
  Renders error responses.

  - For changeset errors, returns a map with detailed field errors
  - For generic errors, returns a map with an error message
  """
  def error(assigns)

  def error(%{changeset: changeset}) do
    %{
      errors:
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          translate_error(msg, opts)
        end)
    }
  end

  def error(%{message: message}) do
    %{error: message}
  end

  @doc """
  Renders a not found error.
  """
  def not_found(_assigns) do
    %{error: "Resource not found"}
  end

  @doc """
  Renders an unauthorized error.
  """
  def unauthorized(_assigns) do
    %{error: "Unauthorized"}
  end

  @doc """
  Renders a forbidden error.
  """
  def forbidden(_assigns) do
    %{error: "Forbidden"}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end

  defp translate_error(msg, opts) when is_binary(msg) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", format_value(value))
    end)
  end

  defp translate_error(msg, _opts) when is_atom(msg) do
    msg
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp translate_error(msg, _opts) when is_list(msg) do
    msg
    |> Enum.map_join(", ", fn
      atom when is_atom(atom) -> Atom.to_string(atom)
      other -> to_string(other)
    end)
    |> String.capitalize()
  end

  defp translate_error(msg, _opts) do
    to_string(msg)
  end

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_integer(value), do: Integer.to_string(value)
  defp format_value(value) when is_float(value), do: Float.to_string(value)
  defp format_value(value) when is_atom(value), do: Atom.to_string(value)
  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(value), do: to_string(value)
end
