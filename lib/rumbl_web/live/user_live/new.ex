defmodule RumblWeb.UserLive.New do
  use RumblWeb, :live_view

  alias Rumbl.Accounts
  alias Rumbl.Accounts.User

  def mount(_params, _session, socket) do
    changeset = Accounts.change_registration(%User{})
    {:ok, assign(socket, changeset: changeset)}
  end

  # Live validation — fires on every keystroke (phx-change="validate")
  # Sets changeset action to :validate so the form shows inline errors while typing
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  # Form submission (phx-submit="save")
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # After registration, redirect to the callback so the controller
        # can write the session (same pattern as SessionLive)
        {:noreply, push_navigate(socket, to: ~p"/sessions/callback?user_id=#{user.id}")}

      {:error, changeset} ->
        # Put the failed changeset back so the form shows errors
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
