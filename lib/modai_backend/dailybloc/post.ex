defmodule ModaiBackend.DailyBloc.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dailybloc" do
    field :title, :string
    field :search, :string
    field :category, :string
    field :content, :string
    field :image, :string, default: ""
    field :published_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :search, :category, :content, :image, :published_at])
    |> validate_required([:title, :search, :category, :content], message: "can't be blank")
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:search, min: 3, max: 255)
    |> unique_constraint(:search)
  end

  @doc false
  def update_changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :search, :category, :content, :image, :published_at])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:search, min: 3, max: 255)
    |> unique_constraint(:search)
  end
end
