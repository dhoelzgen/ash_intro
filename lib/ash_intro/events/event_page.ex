defmodule AshIntro.Events.EventPage do
  use Ash.Resource,
    otp_app: :ash_intro,
    domain: AshIntro.Events,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAi, AshOban],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "event_pages"
    repo AshIntro.Repo
  end

  oban do
    triggers do
      trigger :process do
        actor_persister AshIntro.ActorPersistor
        action :process
        queue :crawls
        where expr(crawl_state == :requested)
        worker_module_name AshIntro.Events.EventPage.AshOban.Worker.Process
        scheduler_module_name AshIntro.Events.EventPage.AshOban.Scheduler.Process
      end
    end
  end

  actions do
    default_accept [:name, :url]
    defaults [:create, :read, :update, :destroy]

    update :crawl do
      accept []
      change set_attribute(:crawl_state, :requested)
      change run_oban_trigger(:process)
    end

    update :process do
      accept []
      require_atomic? false

      change {
        AshIntro.Scraping.Changes.Crawl,
        entity_resource: AshIntro.Events.Event, entity_foreign_key: :event_page_id
      }
    end

    action :extract, {:array, AshIntro.Events.EventDraft} do
      argument :text, :string, allow_nil?: false

      run prompt(
            LangChain.ChatModels.ChatOpenAI.new!(%{
              model: "gpt-4.1",
              stream: true,
              timeout: 120_000,
              recv_timeout: 60_000
            }),
            tools: false,
            prompt: """
            Extract every event from this scraped page:

            <%= @input.arguments.text %>

            Make sure to really extract all events, not just a selection.
            Make sure to return absolute dates. The current date is <%= Date.utc_today() %>
            """
          )
    end

    update :set_ready do
      accept []
      change set_attribute(:crawl_state, :ready)
    end

    update :set_processing do
      accept []
      change set_attribute(:crawl_state, :processing)
    end

    update :set_error do
      accept []
      change set_attribute(:crawl_state, :error)
    end

    update :clear do
      accept []
      require_atomic? false
      argument :events, {:array, :map}, default: []
      change manage_relationship(:events, :events, on_missing: :destroy)
    end
  end

  pub_sub do
    module AshIntroWeb.Endpoint
    prefix "event_pages"

    transform fn %{data: event_page} ->
      %{event_page: event_page}
    end

    publish_all :update, "all", except: [:process]
  end

  attributes do
    timestamps()
    uuid_v7_primary_key :id

    attribute :crawl_state, :atom do
      constraints one_of: [:ready, :requested, :processing, :error]
      default :ready
    end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :url, :string do
      allow_nil? false
    end
  end

  relationships do
    has_many :events, AshIntro.Events.Event do
      public? true
      sort event_date: :asc
    end
  end

  aggregates do
    count :event_count, :events do
      public? true
    end
  end
end
