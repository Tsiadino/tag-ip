defmodule TagIp.Accounts.Auth do
  @moduledoc """
  Context de gestion de l'authentification.
  """

  alias TagIp.Accounts.Auth.User
  alias TagIp.Repo

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    case get_user_by_email(email) do
      %User{} = user ->
        if Bcrypt.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      nil ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def authenticate(_, _), do: Bcrypt.no_user_verify() && {:error, :invalid_credentials}

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def change_registration(attrs \\ %{}) do
    User.registration_changeset(%User{}, attrs)
  end
end