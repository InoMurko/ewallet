defmodule EWalletDB.TransactionConsumption do
  @moduledoc """
  Ecto Schema representing transaction request consumptions.
  """
  use Ecto.Schema
  use EWalletDB.Types.ExternalID
  import Ecto.{Changeset, Query}
  alias Ecto.{Changeset, UUID}

  alias EWalletDB.{
    TransactionConsumption,
    Repo,
    User,
    Token,
    TransactionRequest,
    Wallet,
    Transaction,
    Account,
    ExchangePair
  }

  alias EWalletDB.Helpers.Assoc

  @pending "pending"
  @confirmed "confirmed"
  @failed "failed"
  @expired "expired"
  @approved "approved"
  @rejected "rejected"
  @statuses [@pending, @approved, @rejected, @confirmed, @failed, @expired]

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}

  schema "transaction_consumption" do
    external_id(prefix: "txc_")

    field(:amount, EWalletDB.Types.Integer)
    field(:estimated_consumption_amount, EWalletDB.Types.Integer)
    field(:estimated_request_amount, EWalletDB.Types.Integer)
    field(:estimated_rate, :float)
    field(:correlation_id, :string)
    field(:idempotency_token, :string)

    # State
    field(:status, :string, default: @pending)
    field(:approved_at, :naive_datetime)
    field(:rejected_at, :naive_datetime)
    field(:confirmed_at, :naive_datetime)
    field(:failed_at, :naive_datetime)
    field(:expired_at, :naive_datetime)
    field(:estimated_at, :naive_datetime)

    field(:error_code, :string)
    field(:error_description, :string)

    field(:expiration_date, :naive_datetime)
    field(:metadata, :map, default: %{})
    field(:encrypted_metadata, EWalletDB.Encrypted.Map, default: %{})

    belongs_to(
      :transaction,
      Transaction,
      foreign_key: :transaction_uuid,
      references: :uuid,
      type: UUID
    )

    belongs_to(
      :exchange_pair,
      ExchangePair,
      foreign_key: :exchange_pair_uuid,
      references: :uuid,
      type: UUID
    )

    belongs_to(
      :user,
      User,
      foreign_key: :user_uuid,
      references: :uuid,
      type: UUID
    )

    belongs_to(
      :account,
      Account,
      foreign_key: :account_uuid,
      references: :uuid,
      type: UUID
    )

    belongs_to(
      :transaction_request,
      TransactionRequest,
      foreign_key: :transaction_request_uuid,
      references: :uuid,
      type: UUID
    )

    belongs_to(
      :token,
      Token,
      foreign_key: :token_uuid,
      references: :uuid,
      type: UUID
    )

    belongs_to(
      :wallet,
      Wallet,
      foreign_key: :wallet_address,
      references: :address,
      type: :string
    )

    belongs_to(
      :exchange_account,
      Account,
      foreign_key: :exchange_account_uuid,
      references: :uuid,
      type: UUID
    )

    belongs_to(
      :exchange_wallet,
      Wallet,
      foreign_key: :exchange_wallet_address,
      references: :address,
      type: :string
    )

    timestamps()
  end

  defp changeset(%TransactionConsumption{} = consumption, attrs) do
    consumption
    |> cast(attrs, [
      :amount,
      :estimated_request_amount,
      :estimated_consumption_amount,
      :idempotency_token,
      :correlation_id,
      :user_uuid,
      :account_uuid,
      :transaction_request_uuid,
      :wallet_address,
      :token_uuid,
      :metadata,
      :encrypted_metadata,
      :expiration_date,
      :exchange_account_uuid,
      :exchange_wallet_address,
      :exchange_pair_uuid,
      :estimated_at,
      :estimated_rate
    ])
    |> validate_required([
      :status,
      :idempotency_token,
      :transaction_request_uuid,
      :wallet_address,
      :token_uuid
    ])
    |> validate_number(
      :amount,
      greater_than: 0,
      less_than: 100_000_000_000_000_000_000_000_000_000_000_000
    )
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:idempotency_token)
    |> unique_constraint(:correlation_id)
    |> assoc_constraint(:user)
    |> assoc_constraint(:transaction_request)
    |> assoc_constraint(:wallet)
    |> assoc_constraint(:account)
    |> assoc_constraint(:exchange_pair)
  end

  def approved_changeset(%TransactionConsumption{} = consumption, attrs) do
    consumption
    |> cast(attrs, [:status, :approved_at])
    |> validate_required([:status, :approved_at])
  end

  def rejected_changeset(%TransactionConsumption{} = consumption, attrs) do
    consumption
    |> cast(attrs, [:status, :rejected_at])
    |> validate_required([:status, :rejected_at])
  end

  def confirmed_changeset(%TransactionConsumption{} = consumption, attrs) do
    consumption
    |> cast(attrs, [:status, :confirmed_at, :transaction_uuid])
    |> validate_required([:status, :confirmed_at, :transaction_uuid])
    |> assoc_constraint(:transaction)
  end

  def failed_changeset(%TransactionConsumption{} = consumption, attrs) do
    consumption
    |> cast(attrs, [:status, :failed_at, :transaction_uuid])
    |> validate_required([:status, :failed_at, :transaction_uuid])
    |> assoc_constraint(:transaction)
  end

  def transaction_failure_changeset(%TransactionConsumption{} = consumption, attrs) do
    consumption
    |> cast(attrs, [:status, :failed_at, :error_code, :error_description])
    |> validate_required([:status, :failed_at, :error_code])
  end

  def expired_changeset(%TransactionConsumption{} = consumption, attrs) do
    consumption
    |> cast(attrs, [:status, :expired_at])
    |> validate_required([:status, :expired_at])
  end

  @doc """
  Gets a transaction request consumption.
  """
  @spec get(ExternalID.t()) :: %TransactionConsumption{} | nil
  @spec get(ExternalID.t(), keyword()) :: %TransactionConsumption{} | nil
  def get(id, opts \\ [])

  def get(id, opts) when is_external_id(id) do
    get_by([id: id], opts)
  end

  def get(_id, _opts), do: nil

  @doc """
  Get a consumption using one or more fields.
  """
  @spec get_by(map() | keyword(), List.t()) :: %TransactionConsumption{} | nil
  def get_by(map, opts \\ []) do
    query = TransactionConsumption |> Repo.get_by(map)

    case opts[:preload] do
      nil -> query
      preload -> Repo.preload(query, preload)
    end
  end

  @spec get_final_amount(%TransactionConsumption{}) :: Integer.t() | nil
  def get_final_amount(consumption) do
    consumption = Repo.preload(consumption, [:transaction, :transaction_request])

    case consumption.transaction_request.type do
      "send" -> Assoc.get(consumption, [:transaction, :to_amount])
      "receive" -> Assoc.get(consumption, [:transaction, :from_amount])
    end
  end

  @spec expire_all() :: {integer(), nil | [term()]} | no_return()
  def expire_all do
    now = NaiveDateTime.utc_now()

    TransactionConsumption
    |> where([t], t.status == @pending)
    |> where([t], not is_nil(t.expiration_date))
    |> where([t], t.expiration_date <= ^now)
    |> Repo.update_all(
      [
        set: [
          status: @expired,
          expired_at: NaiveDateTime.utc_now()
        ]
      ],
      returning: true
    )
  end

  @doc """
  Expires the given consumption.
  """
  @spec expire(%TransactionConsumption{}) :: {:ok, %TransactionConsumption{}} | {:error, Map.t()}
  def expire(consumption) do
    consumption
    |> expired_changeset(%{
      status: @expired,
      expired_at: NaiveDateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Expires the given consumption if the expiration date is past.
  """
  @spec expire_if_past_expiration_date(%TransactionConsumption{}) ::
          {:ok, %TransactionConsumption{}} | {:error, Map.t()}
  def expire_if_past_expiration_date(consumption) do
    expired? =
      consumption.expiration_date &&
        NaiveDateTime.compare(consumption.expiration_date, NaiveDateTime.utc_now()) == :lt

    case expired? do
      true -> expire(consumption)
      _ -> {:ok, consumption}
    end
  end

  @spec query_all_for(Atom.t() | String.t(), any()) :: Ecto.Query.t()
  def query_all_for(field_name, value),
    do: where(TransactionConsumption, [t], field(t, ^field_name) == ^value)

  @doc """
  Get all confirmed transaction consumptions.
  """
  @spec all_active_for_request(UUID.t()) :: List.t()
  def all_active_for_request(nil), do: []

  def all_active_for_request(request_uuid) do
    TransactionConsumption
    |> where([t], t.status == @confirmed)
    |> where([t], t.transaction_request_uuid == ^request_uuid)
    |> Repo.all()
  end

  @doc """
  Get all confirmed transaction consumptions for the given user uuid.
  """
  @spec all_active_for_user(UUID.t(), UUID.t()) :: List.t()
  def all_active_for_user(nil, _), do: []

  def all_active_for_user(user_uuid, request_uuid) do
    TransactionConsumption
    |> where([t], t.status == @confirmed)
    |> where([t], t.user_uuid == ^user_uuid)
    |> where([t], t.transaction_request_uuid == ^request_uuid)
    |> Repo.all()
  end

  @doc """
  Inserts a transaction request consumption.
  """
  @spec insert(Map.t()) :: {:ok, %TransactionConsumption{}} | {:error, Map.t()}
  def insert(attrs) do
    changeset = changeset(%TransactionConsumption{}, attrs)
    opts = [on_conflict: :nothing, conflict_target: :idempotency_token]

    case Repo.insert(changeset, opts) do
      {:ok, consumption} ->
        {:ok, get_by(%{idempotency_token: consumption.idempotency_token})}

      error ->
        error
    end
  end

  @doc """
  Approves a consumption.
  """
  @spec approve(%TransactionConsumption{}) :: %TransactionConsumption{}
  def approve(consumption), do: state_transition(consumption, @approved)

  @doc """
  Rejects a consumption.
  """
  @spec reject(%TransactionConsumption{}) :: %TransactionConsumption{}
  def reject(consumption) do
    state_transition(consumption, @rejected)
  end

  @doc """
  Confirms a consumption and saves the transaction ID.
  """
  @spec confirm(%TransactionConsumption{}, %Transaction{}) :: %TransactionConsumption{}
  def confirm(consumption, transaction) do
    state_transition(consumption, @confirmed, transaction.uuid)
  end

  @doc """
  Fails a consumption and saves the transaction ID.
  """
  @spec fail(%TransactionConsumption{}, %Transaction{}) :: %TransactionConsumption{}
  def fail(consumption, %Transaction{} = transaction) do
    state_transition(consumption, @failed, transaction.uuid)
  end

  def fail(consumption, %Changeset{} = _changeset) do
    fail(consumption, :invalid_parameter, nil)
  end

  def fail(consumption, error_code, error_description) do
    data =
      %{
        status: @failed,
        error_code: Atom.to_string(error_code),
        error_description: error_description
      }
      |> Map.put(:failed_at, NaiveDateTime.utc_now())

    {:ok, consumption} =
      consumption
      |> transaction_failure_changeset(data)
      |> Repo.update()

    consumption
  end

  @spec expired?(%TransactionConsumption{}) :: boolean()
  def expired?(consumption) do
    consumption.status == @expired
  end

  def success?(consumption) do
    Enum.member?([@confirmed, @rejected], consumption.status)
  end

  @spec finalized?(%TransactionConsumption{}) :: boolean()
  def finalized?(consumption) do
    Enum.member?([@rejected, @confirmed, @failed, @expired], consumption.status)
  end

  defp state_transition(consumption, status, transaction_uuid \\ nil) do
    fun = String.to_existing_atom("#{status}_changeset")
    timestamp_column = String.to_existing_atom("#{status}_at")

    data =
      %{
        status: status,
        transaction_uuid: transaction_uuid
      }
      |> Map.put(timestamp_column, NaiveDateTime.utc_now())

    {:ok, consumption} =
      __MODULE__
      |> apply(fun, [consumption, data])
      |> Repo.update()

    consumption
  end
end
