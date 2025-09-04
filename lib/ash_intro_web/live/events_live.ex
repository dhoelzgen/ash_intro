defmodule AshIntroWeb.EventsLive do
  use AshIntroWeb, :live_view
  on_mount {AshIntroWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(params, _session, socket) do
    AshIntroWeb.Endpoint.subscribe("events_for_event_page:all")
    AshIntroWeb.Endpoint.subscribe("event_pages:all")

    socket =
      socket
      |> assign(:conversation_id, Map.get(params, "conversation_id", ""))

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> stream(:event_pages, AshIntro.Events.list_event_pages!(load: [:event_count, :events]))
      |> assign(:event_page_form, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("new-event-page", _params, socket) do
    event_page_form =
      AshIntro.Events.form_to_create_event_page(actor: socket.assigns.current_user)
      |> AshPhoenix.Form.ensure_can_submit!()
      |> to_form()

    socket =
      socket
      |> assign(:event_page_form, event_page_form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit-event-page", %{"id" => event_page_id}, socket) do
    event_page =
      AshIntro.Events.get_event_page_by_id!(event_page_id, actor: socket.assigns.current_user)

    event_page_form =
      AshIntro.Events.form_to_update_event_page(event_page, actor: socket.assigns.current_user)
      |> AshPhoenix.Form.ensure_can_submit!()
      |> to_form()

    socket =
      socket
      |> assign(:event_page_form, event_page_form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-event-page-form", _params, socket) do
    socket =
      socket
      |> assign(:event_page_form, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :event_page_form,
       AshPhoenix.Form.validate(socket.assigns.event_page_form, params)
     )}
  end

  @impl true
  def handle_event("submit", %{"form" => form_data}, socket) do
    socket =
      case AshPhoenix.Form.submit(socket.assigns.event_page_form, params: form_data) do
        {:ok, event_page} ->
          # We need to reload the event page, crawler state might have changed
          socket
          |> assign(:event_page_form, nil)
          |> stream_insert(:event_pages, Ash.reload!(event_page))

        {:error, event_page_form} ->
          socket |> assign(:event_page_form, event_page_form)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("destroy-event-page", %{"id" => event_page_id}, socket) do
    event_page =
      AshIntro.Events.get_event_page_by_id!(event_page_id, actor: socket.assigns.current_user)

    socket =
      case AshIntro.Events.destroy_event_page(event_page, actor: socket.assigns.current_user) do
        :ok ->
          socket |> stream_delete(:event_pages, event_page)

        {:error, _error} ->
          socket |> put_flash(:error, "Could not delete event page")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("crawl-event-page", %{"id" => event_page_id}, socket) do
    AshIntro.Events.get_event_page_by_id!(event_page_id, actor: socket.assigns.current_user)
    |> AshIntro.Events.crawl()

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "event_pages:all",
          payload: %{event_page: event_page}
        },
        socket
      ) do
    socket =
      socket
      |> stream_insert(:event_pages, event_page)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "events_for_event_page:all",
          payload: %{event_page_id: page_id} = payload
        },
        socket
      ) do
    send_update(
      AshIntroWeb.EventsLive.EventsForPageComponent,
      id: "events-list-container-#{page_id}",
      payload: payload
    )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-3xl font-bold">Event Pages</h1>
          <.link navigate={~p"/chat/#{@conversation_id}"} class="btn btn-xs btn-link p-0">
            ← Back to Chat
          </.link>
        </div>
        <button class="btn btn-primary" phx-click="new-event-page">
          <.icon name="hero-plus" class="h-5 w-5 mr-2" /> Add New
        </button>
      </div>

      <div id="event-pages" phx-update="stream" class="">
        <.event_page
          :for={{dom_id, event_page} <- @streams.event_pages}
          dom_id={dom_id}
          event_page={event_page}
        />
      </div>
    </div>

    <dialog :if={@event_page_form} id="modal_event_page_form" class="modal" open>
      <div class="modal-box">
        <.event_page_form form={@event_page_form} />
      </div>
    </dialog>
    """
  end

  attr :dom_id, :string, required: true
  attr :event_page, AshIntro.Events.EventPage, required: true

  defp event_page(assigns) do
    text_crawl_button =
      case assigns.event_page.crawl_state do
        :ready -> "Crawl"
        :requested -> "Requested"
        :processing -> "Crawling..."
        :error -> "Retry"
        _ -> "Crawl"
      end

    assigns =
      assigns
      |> assign(:text_crawl_button, text_crawl_button)
      |> assign(
        :class_crawl_button,
        "btn btn-sm btn-primary #{assigns.event_page.crawl_state not in [:ready, :error] && "btn-disabled"}"
      )
      |> assign(
        :class_crawl_icon,
        "h-4 w-4 #{assigns.event_page.crawl_state in [:processing] && "animate-spin"}"
      )

    ~H"""
    <div id={@dom_id} class="my-4 shadow">
      <div class="flex items-center justify-between p-4">
        <div class="flex-1">
          <h3 class="font-semibold text-lg">{@event_page.name}</h3>
          <a href={@event_page.url} target="_blank" class="text-sm text-gray-600 mt-1 hover:underline">
            {@event_page.url}
          </a>
        </div>

        <div class="flex gap-2">
          <button
            phx-click="crawl-event-page"
            phx-value-id={@event_page.id}
            class={@class_crawl_button}
          >
            <.icon
              name="hero-arrow-path"
              class={@class_crawl_icon}
            /> {@text_crawl_button}
          </button>
          <button
            phx-click="edit-event-page"
            phx-value-id={@event_page.id}
            class="btn btn-sm btn-outline"
          >
            <.icon name="hero-pencil" class="h-4 w-4" />
          </button>
          <button
            phx-click="destroy-event-page"
            phx-value-id={@event_page.id}
            class="btn btn-sm btn-outline"
            data-confirm="Are you sure you want to delete this event page?"
          >
            <.icon name="hero-trash" class="h-4 w-4" />
          </button>
        </div>
      </div>

      <.live_component
        module={AshIntroWeb.EventsLive.EventsForPageComponent}
        id={"events-list-container-#{@event_page.id}"}
        event_page={@event_page}
      />
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true

  defp event_page_form(assigns) do
    ~H"""
    <.form
      :let={form}
      as={:form}
      for={@form}
      id="event_page_form"
      phx-change="validate"
      phx-submit="submit"
    >
      <div class="space-y-4">
        <.input field={form[:name]} label="Name" placeholder="Enter event page name" />
        <.input field={form[:url]} label="URL" type="url" placeholder="https://example.com/events" />
      </div>

      <div class="flex justify-end space-x-3 pt-6">
        <button
          id="event-page-form-cancel-button"
          type="button"
          class="btn btn-ghost"
          phx-click="cancel-event-page-form"
          phx-hook="ModalEsc"
        >
          Cancel
        </button>
        <button type="submit" class="btn btn-primary">
          Save
        </button>
      </div>
    </.form>
    """
  end
end
