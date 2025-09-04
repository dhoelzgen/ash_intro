defmodule AshIntro.Events.Event do
  use Ash.Resource,
    otp_app: :ash_intro,
    domain: AshIntro.Events,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "events"
    repo AshIntro.Repo

    references do
      reference :event_page, index?: true, on_delete: :delete
    end
  end

  actions do
    default_accept [:event_page_id, :name, :description, :event_date, :event_location]
    defaults [:create, :read, :update, :destroy]

    read :search do
      description "List events, optionally filtering by name."

      argument :query, :ci_string do
        description "Return only events with names including the given value."
        constraints allow_empty?: true
        default ""
      end

      filter expr(contains(name, ^arg(:query)))

      pagination keyset?: true, default_limit: 25
    end
  end

  pub_sub do
    module AshIntroWeb.Endpoint
    prefix "events_for_event_page"

    transform fn %{data: event, action: action} ->
      %{event: event, event_page_id: event.event_page_id, action: action.name}
    end

    publish :create, "all"
    publish :update, "all"
    publish :destroy, "all"
  end

  attributes do
    timestamps()
    uuid_v7_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :description, :string do
      public? true
    end

    attribute :event_date, :datetime do
      public? true
      allow_nil? false
    end

    attribute :event_location, :string do
      public? true
    end
  end

  relationships do
    belongs_to :event_page, AshIntro.Events.EventPage do
      public? true
      allow_nil? false
    end
  end

  calculations do
    calculate :event_page_name, :string, expr(event_page.name) do
      public? true
    end
  end
end
