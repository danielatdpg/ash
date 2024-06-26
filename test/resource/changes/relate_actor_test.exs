defmodule Ash.Test.Resource.Changes.RelateActorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Ash.Test.Domain, as: Domain

  defmodule Author do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
    end

    actions do
      default_accept :*
      defaults [:read, create: :*]

      create :create_with_account do
        argument :account, :map
        change manage_relationship(:account, type: :append_and_remove)
      end
    end

    relationships do
      belongs_to :account, Ash.Test.Resource.Changes.RelateActorTest.Account do
        public?(true)
      end
    end
  end

  defmodule Account do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
    end

    actions do
      default_accept :*
      defaults [:read, create: :*]
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id

      attribute :text, :string do
        public?(true)
      end
    end

    relationships do
      belongs_to :author, Ash.Test.Resource.Changes.RelateActorTest.Author do
        public?(true)
        allow_nil? true
      end

      belongs_to :account, Ash.Test.Resource.Changes.RelateActorTest.Account do
        public?(true)
        allow_nil? true
      end
    end

    actions do
      default_accept :*

      defaults [:read]

      create :create_with_actor do
        change relate_actor(:author)
      end

      create :create_with_actor_field do
        change relate_actor(:account, field: :account)
      end

      create :create_possibly_without_actor do
        change relate_actor(:author, allow_nil?: true)
      end
    end
  end

  defmodule PostRequiringActor do
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id

      attribute :text, :string do
        public?(true)
      end
    end

    relationships do
      belongs_to :author, Ash.Test.Resource.Changes.RelateActorTest.Author do
        public?(true)
        allow_nil? false
      end

      belongs_to :account, Ash.Test.Resource.Changes.RelateActorTest.Account do
        public?(true)
        allow_nil? true
      end
    end

    actions do
      default_accept :*

      defaults [:read]

      create :create_with_actor do
        change relate_actor(:author)
      end

      create :create_with_actor_field do
        change relate_actor(:account, field: :account)
      end

      create :create_possibly_without_actor do
        change relate_actor(:author, allow_nil?: true)
      end
    end
  end

  test "relate_actor change with defaults work" do
    actor =
      Author
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!()

    params = [text: "foo"]

    post_with =
      Post
      |> Ash.Changeset.for_create(:create_with_actor, params, actor: actor)
      |> Ash.create!()

    assert post_with.author_id == actor.id

    {:error, changeset} =
      Post
      |> Ash.Changeset.for_create(:create_with_actor, params, actor: nil)
      |> Ash.create()

    assert changeset.errors |> Enum.count() == 1
  end

  test "relate_actor change works with streaming bulk create" do
    actor =
      Author
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!()

    actor_id = actor.id

    assert %Ash.BulkResult{
             records: [
               %{author_id: ^actor_id}
             ],
             errors: []
           } =
             [%{text: "foo"}]
             |> Ash.bulk_create!(PostRequiringActor, :create_with_actor,
               actor: actor,
               return_errors?: true,
               return_records?: true
             )
  end

  test "relate_actor change with field" do
    account =
      Account
      |> Ash.Changeset.for_create(:create, %{})
      |> Ash.create!()

    actor =
      Author
      |> Ash.Changeset.for_create(:create_with_account, %{account: account})
      |> Ash.create!()

    post =
      Post
      |> Ash.Changeset.for_create(:create_with_actor_field, %{text: "foo"}, actor: actor)
      |> Ash.create!()

    assert post.account_id == account.id
  end

  test "relate_actor change with field when field is nil" do
    actor =
      Author
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!()
      |> Ash.load!(:account)

    {:error, changeset} =
      Post
      |> Ash.Changeset.for_create(:create_with_actor_field, %{text: "foo"}, actor: actor)
      |> Ash.create()

    assert changeset.errors |> Enum.count() == 1
  end

  test "relate_actor change with `allow_nil?: true` allows both nil and an actor" do
    actor =
      Author
      |> Ash.Changeset.for_create(:create)
      |> Ash.create!()

    params = [text: "foo"]

    post_with =
      Post
      |> Ash.Changeset.for_create(:create_possibly_without_actor, params, actor: actor)
      |> Ash.create!()

    assert post_with.author_id == actor.id

    post_without =
      Post
      |> Ash.Changeset.for_create(:create_possibly_without_actor, params, actor: nil)
      |> Ash.create!()

    assert is_nil(post_without.author_id)
  end
end
